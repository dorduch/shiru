import type {Firestore} from "firebase-admin/firestore";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {extensionForMimeType, hashInviteToken, isInviteExpired} from "./domain";
import {flipVoiceToQueued} from "./voiceClone";

/**
 * Same generic message for every redeem-failure reason (not-found, wrong
 * status, expired) — a prober must never be able to distinguish which case
 * applied.
 */
export const INVALID_REDEEM_MESSAGE = "This invite link is no longer valid.";

/**
 * Same generic message for a submit/upload call whose invite session isn't
 * currently active: no matching redeemed invite, mismatched parentUid/voiceId,
 * or past the 2h post-redemption window.
 */
export const INVALID_SESSION_MESSAGE = "This invite session is no longer valid.";

/** Bounded window after redemption during which submit/upload are allowed. */
const SESSION_WINDOW_MS = 2 * 60 * 60 * 1000;

/** Max decoded sample size accepted by uploadVoiceInviteSample. */
const MAX_SAMPLE_BYTES = 8 * 1024 * 1024;

/**
 * The 5 guided-capture prompts, copied verbatim from `_capturePrompts` in
 * app/lib/ui/family_voices_screens.dart (GuidedCaptureScreen). This server
 * copy becomes the single source of truth for `redeemVoiceInvite`'s
 * response — keep both in sync if the in-app copy ever changes.
 */
export const INVITE_PROMPTS: {label: string; text: string}[] = [
  {
    label: "Warm & friendly",
    text: "Once upon a time, in a cosy little cottage at the edge of a friendly forest, there lived a curious rabbit who loved to collect shiny pebbles.",
  },
  {
    label: "Calm & slow",
    text: "The stars began to appear one by one, like tiny lanterns being lit across a velvet sky, and the world grew quiet and still.",
  },
  {
    label: "Excited & bright",
    text: "\"We found it!\" she cried, jumping up and down. \"The golden feather is right here, hidden inside the old oak tree — just like the map said!\"",
  },
  {
    label: "Gentle & soft",
    text: "He tucked the little bear snugly under the blanket, whispered goodnight to the moon peeking through the curtain, and smiled.",
  },
  {
    label: "Curious & wondering",
    text: "What could be inside? She pressed her ear to the shell and heard — very faintly — the sound of waves, and laughter, and something magical.",
  },
];

export type RedeemVoiceInviteResult = {
  customToken: string;
  name: string;
  relationship: string;
  prompts: {label: string; text: string}[];
  expiresAt: string;
};

/**
 * Core logic behind the `redeemVoiceInvite` callable (no prior auth). Takes
 * the raw token (already shape-validated by the wrapper via
 * `isValidInviteToken`) plus injectable `nowMillis`/`createCustomToken` so
 * it's exercisable with a hand-rolled Firestore fake in vitest, mirroring
 * `createVoiceInviteCore`.
 *
 * Every failure reason (invite not found, wrong status, expired) throws the
 * SAME generic HttpsError so a prober can never learn which case applied.
 * For the expired case the doc is still flipped to "expired" — but that flip
 * must happen as a *committed* transaction outcome, not a throw from inside
 * the transaction callback: Firestore discards all queued writes if the
 * callback throws, so the write and the generic-error throw are deliberately
 * split — the transaction always returns an outcome object, and the throw
 * happens outside it, once the transaction (including the "expired" write)
 * has already settled.
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

  type Outcome =
    | {ok: true; parentUid: string; voiceId: string; expiresAt: Timestamp}
    | {ok: false};

  const outcome: Outcome = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(inviteRef);
    if (!snap.exists) return {ok: false};
    const data = snap.data()!;
    if (data.status !== "pending") return {ok: false};

    const expiresAt = data.expiresAt as Timestamp;
    if (isInviteExpired(expiresAt.toMillis(), nowMillis)) {
      transaction.update(inviteRef, {status: "expired"});
      return {ok: false};
    }

    transaction.update(inviteRef, {
      status: "redeemed",
      redeemedAt: FieldValue.serverTimestamp(),
      redeemedSyntheticUid: syntheticUid,
    });
    return {ok: true, parentUid: data.parentUid as string, voiceId: data.voiceId as string, expiresAt};
  });

  if (!outcome.ok) {
    throw new HttpsError("failed-precondition", INVALID_REDEEM_MESSAGE);
  }
  const {parentUid, voiceId, expiresAt} = outcome;

  const voiceSnap = await db.doc(`users/${parentUid}/voices/${voiceId}`).get();
  const voiceData = voiceSnap.data() ?? {};
  const name = typeof voiceData.name === "string" ? voiceData.name : "";
  const relationship = typeof voiceData.relationship === "string" ? voiceData.relationship : "";

  // PINNED claims shape: {invite: true, parentUid, voiceId}. The response
  // NEVER includes parentUid/voiceId — submitVoiceInvite/uploadVoiceInviteSample
  // re-derive them from the verified token claims, never from client input.
  const customToken = await createCustomToken(syntheticUid, {invite: true, parentUid, voiceId});

  return {
    customToken,
    name,
    relationship,
    prompts: INVITE_PROMPTS,
    expiresAt: expiresAt.toDate().toISOString(),
  };
}

export type InviteClaims = {parentUid: string; voiceId: string; syntheticUid: string};

/**
 * Guards `submitVoiceInvite`/`uploadVoiceInviteSample`: requires the
 * `invite: true` custom claim minted by `redeemVoiceInvite`, and reads
 * `parentUid`/`voiceId` ONLY from the verified token — never from
 * request.data — so a client can never claim someone else's voice.
 * Mirrors `requireTrusted`'s calling convention (takes the whole request-like
 * object) so both guards read the same at call sites in index.ts.
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
 * Shared session-liveness check for submit + upload: the invite doc matching
 * this synthetic uid must still say "redeemed" (not re-redeemed, canceled,
 * etc.), must match the claimed parentUid/voiceId, and must be within the 2h
 * post-redemption window. Enforced on BOTH submit and upload — not just
 * submit — because the `invite: true` claim rides in a Firebase ID token
 * that can be refreshed and kept alive well past 2h; without re-checking on
 * every privileged call, a leaked/persisted invite session could upload
 * indefinitely, which is exactly the window this check exists to close.
 * Same generic error for every failure reason.
 */
async function assertActiveInviteSession(
  db: Firestore,
  syntheticUid: string,
  parentUid: string,
  voiceId: string,
  nowMillis: number,
): Promise<void> {
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
}

/**
 * Core logic behind `submitVoiceInvite`. `parentUid`/`voiceId`/`syntheticUid`
 * come from `requireInviteClaims` (verified token), never request.data.
 * Determines `samplePaths` by LISTING Storage under
 * `voice-samples/{parentUid}/{voiceId}/` (the bucket's `getFiles` list API)
 * rather than trusting any client-supplied list, then reuses
 * `flipVoiceToQueued` — the exact same transition `submitVoiceClone` uses.
 *
 * Index note: the `redeemedSyntheticUid` lookup inside
 * `assertActiveInviteSession` is a single-field equality query, which
 * Firestore auto-indexes by default — no composite index is required.
 */
export async function submitVoiceInviteCore(
  db: Firestore,
  bucket: {getFiles: (options: {prefix: string}) => Promise<[{name: string}[], ...unknown[]]>},
  parentUid: string,
  voiceId: string,
  syntheticUid: string,
  nowMillis: number,
): Promise<void> {
  await assertActiveInviteSession(db, syntheticUid, parentUid, voiceId, nowMillis);

  const [files] = await bucket.getFiles({prefix: `voice-samples/${parentUid}/${voiceId}/`});
  const samplePaths = files.map((f) => f.name);
  if (samplePaths.length === 0) {
    throw new HttpsError("failed-precondition", "No recordings were found to submit.");
  }

  await flipVoiceToQueued(db, parentUid, voiceId, samplePaths);
}

/**
 * Core logic behind `uploadVoiceInviteSample`. Re-checks the same
 * active-session window as submit (see `assertActiveInviteSession`), then
 * validates `idx`/size/mimeType, then writes via Admin SDK — which bypasses
 * `storage.rules` entirely, so this validation is the only gate.
 */
export async function uploadVoiceInviteSampleCore(
  db: Firestore,
  bucket: {file: (path: string) => {save: (buf: Buffer, opts: {contentType: string}) => Promise<void>}},
  parentUid: string,
  voiceId: string,
  syntheticUid: string,
  nowMillis: number,
  idx: number,
  dataBase64: string,
  mimeType: string,
): Promise<{path: string}> {
  await assertActiveInviteSession(db, syntheticUid, parentUid, voiceId, nowMillis);

  if (!Number.isInteger(idx) || idx < 0 || idx > 4) {
    throw new HttpsError("invalid-argument", "idx must be an integer in [0, 4].");
  }

  let ext: string;
  try {
    ext = extensionForMimeType(mimeType);
  } catch {
    throw new HttpsError("invalid-argument", "Unsupported mimeType.");
  }

  const buffer = Buffer.from(dataBase64, "base64");
  if (buffer.length > MAX_SAMPLE_BYTES) {
    throw new HttpsError("invalid-argument", "Sample exceeds the 8MB limit.");
  }

  const path = `voice-samples/${parentUid}/${voiceId}/${idx}.${ext}`;
  await bucket.file(path).save(buffer, {contentType: mimeType});
  return {path};
}
