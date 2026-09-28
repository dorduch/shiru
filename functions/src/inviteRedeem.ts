import {randomBytes} from "node:crypto";
import type {Firestore} from "firebase-admin/firestore";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {
  ALLOWED_READING_MIME_TYPES,
  extensionForMimeType,
  hashInviteToken,
  isAllowedReadingMimeType,
  isInviteExpired,
  MAX_READING_BYTES,
  MAX_READING_DURATION_SECONDS,
} from "./domain";

/**
 * Same generic message for every redeem-failure reason (not-found, wrong
 * status, expired) — a prober must never be able to distinguish which case
 * applied. Status lookups for already-submitted invites are a deliberate
 * exception (see RedeemVoiceInviteResult kind:"status").
 */
export const INVALID_REDEEM_MESSAGE = "This invite link is no longer valid.";

/**
 * Same generic message for a submit/upload call whose invite session isn't
 * currently active: no matching redeemed invite, mismatched parentUid/voiceId,
 * or past the 2h post-redemption window.
 */
export const INVALID_SESSION_MESSAGE = "This invite session is no longer valid.";

/** Bounded window after redemption during which prepare/submit are allowed. */
const SESSION_WINDOW_MS = 2 * 60 * 60 * 1000;

export type ApprovalStatus = "pending" | "approved" | "rejected";

export type RedeemVoiceInviteResult =
  | {
    kind: "session";
    customToken: string;
    name: string;
    relationship: string;
    expiresAt: string;
    maxDurationSeconds: number;
    maxBytes: number;
    allowedMimeTypes: readonly string[];
  }
  | {
    kind: "status";
    approvalStatus: ApprovalStatus;
    name: string;
    relationship: string;
  };

type InviteDoc = {
  parentUid: string;
  voiceId: string;
  status: string;
  expiresAt: Timestamp;
  redeemedAt?: Timestamp | null;
  redeemedSyntheticUid?: string | null;
  readingId?: string | null;
};

/**
 * Core logic behind the `redeemVoiceInvite` callable (no prior auth).
 *
 * - pending + not expired → flip to redeemed, mint invite custom token, return
 *   a full-reading capture session (no clone-sample prompts).
 * - submitted → return approval status (pending/approved/rejected) so the
 *   relative can reopen the link without email/push notify. No upload UI.
 * - anything else (missing, canceled, expired, abandoned redeemed) → same
 *   generic dead-end error.
 *
 * Expired pending invites are flipped to "expired" inside the transaction
 * before the generic error is thrown outside it (Firestore discards writes if
 * the callback throws).
 */
export async function redeemVoiceInviteCore(
  db: Firestore,
  token: string,
  nowMillis: number,
  createCustomToken: (uid: string, claims: Record<string, unknown>) => Promise<string>,
): Promise<RedeemVoiceInviteResult> {
  const tokenHash = hashInviteToken(token);
  const syntheticUid = `invite:${tokenHash.slice(0, 32)}`;
  const inviteRef = db.doc(`voiceInvites/${tokenHash}`);

  type TxOutcome =
    | {ok: true; parentUid: string; voiceId: string; expiresAt: Timestamp}
    | {ok: false; reason: "invalid"}
    | {ok: false; reason: "status"; parentUid: string; voiceId: string; readingId: string};

  const outcome: TxOutcome = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(inviteRef);
    if (!snap.exists) return {ok: false, reason: "invalid"};
    const data = snap.data() as InviteDoc;

    if (data.status === "submitted" && typeof data.readingId === "string" && data.readingId.length > 0) {
      return {
        ok: false,
        reason: "status",
        parentUid: data.parentUid,
        voiceId: data.voiceId,
        readingId: data.readingId,
      };
    }

    if (data.status !== "pending") return {ok: false, reason: "invalid"};

    const expiresAt = data.expiresAt;
    if (isInviteExpired(expiresAt.toMillis(), nowMillis)) {
      transaction.update(inviteRef, {status: "expired"});
      return {ok: false, reason: "invalid"};
    }

    transaction.update(inviteRef, {
      status: "redeemed",
      redeemedAt: FieldValue.serverTimestamp(),
      redeemedSyntheticUid: syntheticUid,
    });
    return {ok: true, parentUid: data.parentUid, voiceId: data.voiceId, expiresAt};
  });

  if (!outcome.ok && outcome.reason === "status") {
    const [voiceSnap, readingSnap] = await Promise.all([
      db.doc(`users/${outcome.parentUid}/voices/${outcome.voiceId}`).get(),
      db.doc(`users/${outcome.parentUid}/relativeReadings/${outcome.readingId}`).get(),
    ]);
    const voiceData = voiceSnap.data() ?? {};
    const readingStatus = readingSnap.data()?.status;
    const approvalStatus: ApprovalStatus =
      readingStatus === "approved" || readingStatus === "rejected" ? readingStatus : "pending";
    return {
      kind: "status",
      approvalStatus,
      name: typeof voiceData.name === "string" ? voiceData.name : "",
      relationship: typeof voiceData.relationship === "string" ? voiceData.relationship : "",
    };
  }

  if (!outcome.ok) {
    throw new HttpsError("failed-precondition", INVALID_REDEEM_MESSAGE);
  }

  const {parentUid, voiceId, expiresAt} = outcome;
  const voiceSnap = await db.doc(`users/${parentUid}/voices/${voiceId}`).get();
  const voiceData = voiceSnap.data() ?? {};
  const name = typeof voiceData.name === "string" ? voiceData.name : "";
  const relationship = typeof voiceData.relationship === "string" ? voiceData.relationship : "";

  // PINNED claims shape: {invite: true, parentUid, voiceId}. The response
  // NEVER includes parentUid/voiceId — prepare/submit re-derive them from the
  // verified token claims, never from client input.
  const customToken = await createCustomToken(syntheticUid, {invite: true, parentUid, voiceId});

  return {
    kind: "session",
    customToken,
    name,
    relationship,
    expiresAt: expiresAt.toDate().toISOString(),
    maxDurationSeconds: MAX_READING_DURATION_SECONDS,
    maxBytes: MAX_READING_BYTES,
    allowedMimeTypes: ALLOWED_READING_MIME_TYPES,
  };
}

export type InviteClaims = {parentUid: string; voiceId: string; syntheticUid: string};

/**
 * Guards prepare/submit: requires the `invite: true` custom claim minted by
 * `redeemVoiceInvite`, and reads `parentUid`/`voiceId` ONLY from the verified
 * token — never from request.data.
 */
export function requireInviteClaims(request: {auth?: unknown}): InviteClaims {
  const auth = request.auth as {uid: string; token?: Record<string, unknown>} | undefined;
  if (!auth || auth.token?.invite !== true) {
    throw new HttpsError("unauthenticated", "A valid invite session is required.");
  }
  const parentUid = auth.token?.parentUid;
  const voiceId = auth.token?.voiceId;
  if (typeof parentUid !== "string" || typeof voiceId !== "string") {
    throw new HttpsError("unauthenticated", "A valid invite session is required.");
  }
  return {parentUid, voiceId, syntheticUid: auth.uid};
}

/**
 * Shared session-liveness check for prepare + submit. Same generic error for
 * every failure reason. Invite must still be "redeemed" (not yet submitted),
 * match claims, and be within the 2h post-redemption window.
 */
async function assertActiveInviteSession(
  db: Firestore,
  syntheticUid: string,
  parentUid: string,
  voiceId: string,
  nowMillis: number,
): Promise<{inviteRefPath: string}> {
  const snap = await db.collection("voiceInvites").where("redeemedSyntheticUid", "==", syntheticUid).get();
  const doc = snap.docs[0];
  const data = doc?.data();
  const redeemedAt = data?.redeemedAt as Timestamp | null | undefined;
  const withinWindow = !!redeemedAt && (nowMillis - redeemedAt.toMillis()) < SESSION_WINDOW_MS;
  const valid = !!doc && data?.status === "redeemed" &&
    data?.parentUid === parentUid && data?.voiceId === voiceId && withinWindow;
  if (!valid) {
    throw new HttpsError("failed-precondition", INVALID_SESSION_MESSAGE);
  }
  return {inviteRefPath: doc.ref.path};
}

export type PrepareStoryInviteUploadResult = {
  readingId: string;
  storagePath: string;
  maxBytes: number;
};

/**
 * Mints a readingId + Storage object path for a single full-reading upload.
 * Does NOT create a parent pending doc — that happens only in submit after
 * the object exists, so a failed/abandoned upload leaves zero orphan pending.
 */
export async function prepareStoryInviteUploadCore(
  db: Firestore,
  parentUid: string,
  voiceId: string,
  syntheticUid: string,
  nowMillis: number,
  mimeType: string,
  newReadingId: () => string = () => randomBytes(16).toString("hex"),
): Promise<PrepareStoryInviteUploadResult> {
  await assertActiveInviteSession(db, syntheticUid, parentUid, voiceId, nowMillis);

  if (!isAllowedReadingMimeType(mimeType)) {
    throw new HttpsError("invalid-argument", "Unsupported mimeType. Use audio/webm, audio/mp4, or audio/aac.");
  }

  let ext: string;
  try {
    ext = extensionForMimeType(mimeType);
  } catch {
    throw new HttpsError("invalid-argument", "Unsupported mimeType.");
  }

  const readingId = newReadingId();
  if (!/^[a-f0-9]{16,64}$/i.test(readingId)) {
    throw new HttpsError("internal", "Failed to mint reading id.");
  }

  const storagePath = `relative-readings/${parentUid}/${readingId}/reading.${ext}`;
  return {readingId, storagePath, maxBytes: MAX_READING_BYTES};
}

type StorageFileMeta = {
  exists: boolean;
  size: number;
  contentType: string | undefined;
};

/**
 * Finalizes a full reading: verifies the Storage object (size + mime), creates
 * `users/{parentUid}/relativeReadings/{readingId}` with status "pending", and
 * flips the invite to "submitted". No ElevenLabs / voice-clone path.
 *
 * Idempotent: re-submit of the same readingId after success is a no-op success.
 * Creates the pending doc only after the file check passes (zero orphan pending
 * on network fail before submit).
 */
export async function submitStoryInviteReadingCore(
  db: Firestore,
  getFileMeta: (path: string) => Promise<StorageFileMeta>,
  parentUid: string,
  voiceId: string,
  syntheticUid: string,
  nowMillis: number,
  readingId: string,
  mimeType: string,
  durationSeconds: number | null,
): Promise<{readingId: string; status: "pending"}> {
  if (typeof readingId !== "string" || !/^[a-f0-9]{16,64}$/i.test(readingId)) {
    throw new HttpsError("invalid-argument", "readingId is required.");
  }
  if (!isAllowedReadingMimeType(mimeType)) {
    throw new HttpsError("invalid-argument", "Unsupported mimeType. Use audio/webm, audio/mp4, or audio/aac.");
  }
  if (durationSeconds !== null) {
    if (typeof durationSeconds !== "number" || !Number.isFinite(durationSeconds) || durationSeconds < 0) {
      throw new HttpsError("invalid-argument", "durationSeconds must be a non-negative number.");
    }
    if (durationSeconds > MAX_READING_DURATION_SECONDS) {
      throw new HttpsError("invalid-argument", "Recording exceeds the 15 minute limit.");
    }
  }

  let ext: string;
  try {
    ext = extensionForMimeType(mimeType);
  } catch {
    throw new HttpsError("invalid-argument", "Unsupported mimeType.");
  }

  const {inviteRefPath} = await assertActiveInviteSession(db, syntheticUid, parentUid, voiceId, nowMillis);
  const storagePath = `relative-readings/${parentUid}/${readingId}/reading.${ext}`;

  const meta = await getFileMeta(storagePath);
  if (!meta.exists || meta.size <= 0) {
    throw new HttpsError("failed-precondition", "No recording was found to submit.");
  }
  if (meta.size > MAX_READING_BYTES) {
    throw new HttpsError("invalid-argument", "Recording exceeds the 25MB limit.");
  }
  const storedType = (meta.contentType || "").split(";")[0].trim();
  if (storedType && storedType !== mimeType) {
    throw new HttpsError("invalid-argument", "Uploaded file mimeType does not match.");
  }

  const voiceSnap = await db.doc(`users/${parentUid}/voices/${voiceId}`).get();
  const voiceData = voiceSnap.data() ?? {};
  const name = typeof voiceData.name === "string" ? voiceData.name : "";
  const relationship = typeof voiceData.relationship === "string" ? voiceData.relationship : "";

  const readingRef = db.doc(`users/${parentUid}/relativeReadings/${readingId}`);
  const inviteRef = db.doc(inviteRefPath);

  await db.runTransaction(async (transaction) => {
    const [inviteSnap, readingSnap] = await Promise.all([
      transaction.get(inviteRef),
      transaction.get(readingRef),
    ]);
    const inviteData = inviteSnap.data();
    if (!inviteSnap.exists) {
      throw new HttpsError("failed-precondition", INVALID_SESSION_MESSAGE);
    }

    // Idempotent success if this invite already submitted this reading.
    if (inviteData?.status === "submitted" && inviteData?.readingId === readingId && readingSnap.exists) {
      return;
    }
    if (inviteData?.status !== "redeemed") {
      throw new HttpsError("failed-precondition", INVALID_SESSION_MESSAGE);
    }

    transaction.set(readingRef, {
      voiceId,
      inviteTokenHash: inviteRefPath.split("/")[1] ?? null,
      name,
      relationship,
      status: "pending",
      storagePath,
      mimeType,
      byteSize: meta.size,
      durationSeconds: durationSeconds,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(inviteRef, {
      status: "submitted",
      readingId,
      submittedAt: FieldValue.serverTimestamp(),
    });
  });

  return {readingId, status: "pending"};
}
