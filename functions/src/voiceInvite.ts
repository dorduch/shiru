import type {Firestore} from "firebase-admin/firestore";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {hashInviteToken, utcQuotaDay} from "./domain";
import {isFamilyVoiceEnabled} from "./voiceClone";

/** Invite links are valid for 7 days from creation. */
export const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/** Per-user, per-UTC-day cap on invite creation (mirrors createStoryJob's dailyLimit pattern). */
export const DAILY_INVITE_QUOTA = 5;

/** Pure URL builder — kept separate from I/O so it's directly unit-testable. */
export function inviteUrl(host: string, token: string): string {
  return `${host}/invite/${token}`;
}

export type CreateVoiceInviteResult = {url: string; expiresAt: Timestamp};

/**
 * Core logic behind the `createVoiceInvite` callable. Lives outside index.ts
 * (like `flipVoiceToQueued` in voiceClone.ts) so it can be exercised with a
 * hand-rolled Firestore fake in tests — index.ts can't be imported directly
 * in vitest because module load calls `initializeApp()`/`getStorage().bucket()`,
 * which throw without a configured default bucket.
 *
 * The callable wrapper is responsible for `requireTrusted`, arg validation via
 * `validateCreateInviteRequest`, and generating `token`/`nowMillis`; this
 * function takes them as plain inputs so tests can assert exact doc paths,
 * URLs, and expiry timestamps deterministically.
 */
export async function createVoiceInviteCore(
  db: Firestore,
  uid: string,
  voiceId: string,
  token: string,
  nowMillis: number,
  host: string,
): Promise<CreateVoiceInviteResult> {
  // Family-voice entitlement gate. Matches createStoryJob's error code
  // (invalid-argument) rather than flipVoiceToQueued's failed-precondition —
  // this is the one place this helper intentionally diverges from the
  // sibling helper it's modeled on.
  const enabled = await isFamilyVoiceEnabled(db);
  if (!enabled) throw new HttpsError("invalid-argument", "family-voice-disabled");

  // Voice existence + status gate, read before the transaction (same
  // low-stakes TOCTOU tradeoff createStoryJob makes for its config/entitlement
  // reads outside the transaction).
  const voiceRef = db.doc(`users/${uid}/voices/${voiceId}`);
  const voiceSnap = await voiceRef.get();
  if (!voiceSnap.exists) throw new HttpsError("not-found", "Voice not found.");
  const voiceStatus = voiceSnap.data()?.status;
  if (voiceStatus !== "consented" && voiceStatus !== "failed") {
    throw new HttpsError("failed-precondition", "Voice is not in consented or failed state.");
  }

  const day = utcQuotaDay(new Date(nowMillis));
  const quotaRef = db.doc(`users/${uid}/inviteQuota/${day}`);
  const tokenHash = hashInviteToken(token);
  const inviteRef = db.doc(`voiceInvites/${tokenHash}`);
  const pendingQuery = db.collection("voiceInvites")
    .where("parentUid", "==", uid)
    .where("voiceId", "==", voiceId)
    .where("status", "==", "pending");

  // serverTimestamp() can't be read back synchronously for the response, so
  // expiresAt is computed client(server-function)-side as now + 7d. This is
  // the value both persisted on the doc and returned to the caller — no
  // discrepancy, just not literally Firestore's own commit time.
  const expiresAt = Timestamp.fromMillis(nowMillis + INVITE_TTL_MS);

  await db.runTransaction(async (transaction) => {
    // Reads first (Firestore transactions require all reads before writes).
    const [quotaSnap, pendingSnap] = await Promise.all([
      transaction.get(quotaRef),
      transaction.get(pendingQuery),
    ]);

    const reserved = (quotaSnap.data()?.reserved as number | undefined) ?? 0;
    if (reserved >= DAILY_INVITE_QUOTA) {
      throw new HttpsError("resource-exhausted", "daily-invite-limit");
    }

    // Supersede: cancel any other pending invite for this {uid, voiceId}.
    for (const doc of pendingSnap.docs) {
      transaction.update(doc.ref, {status: "canceled"});
    }

    transaction.set(quotaRef, {reserved: reserved + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    transaction.create(inviteRef, {
      parentUid: uid,
      voiceId,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
      redeemedAt: null,
      redeemedSyntheticUid: null,
    });
  });

  return {url: inviteUrl(host, token), expiresAt};
}
