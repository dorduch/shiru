import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  prepareStoryInviteUploadCore, requireInviteClaims, submitStoryInviteReadingCore,
} from "./inviteRedeem";

// Relies on initializeApp() already having been called from index.ts.
const db = getFirestore();
const bucket = getStorage().bucket();

// Invite-claim gated (see requireInviteClaims), no App Check — same reasoning
// as redeemVoiceInvite. Mints a Storage path for one full reading; the web
// client uploads via the Firebase Storage SDK under invite custom-token
// claims. Pending parent docs are created only in submitStoryInviteReading.
export const prepareStoryInviteUpload = onCall({enforceAppCheck: false}, async (request) => {
  const {parentUid, voiceId, syntheticUid} = requireInviteClaims(request);
  const data = request.data as Record<string, unknown>;
  const mimeType = data?.mimeType;
  if (typeof mimeType !== "string") {
    throw new HttpsError("invalid-argument", "mimeType is required.");
  }
  return prepareStoryInviteUploadCore(db, parentUid, voiceId, syntheticUid, Date.now(), mimeType);
});

// Invite-claim gated, no App Check. Verifies the uploaded object (25MB + mime),
// creates users/{parentUid}/relativeReadings/{readingId} as pending, and marks
// the invite submitted. No ElevenLabs / voice-clone path.
export const submitStoryInviteReading = onCall({enforceAppCheck: false}, async (request) => {
  const {parentUid, voiceId, syntheticUid} = requireInviteClaims(request);
  const data = request.data as Record<string, unknown>;
  const readingId = data?.readingId;
  const mimeType = data?.mimeType;
  const durationSeconds = data?.durationSeconds;
  if (typeof readingId !== "string" || typeof mimeType !== "string") {
    throw new HttpsError("invalid-argument", "readingId and mimeType are required.");
  }
  const duration = durationSeconds === undefined || durationSeconds === null
    ? null
    : durationSeconds;
  if (duration !== null && typeof duration !== "number") {
    throw new HttpsError("invalid-argument", "durationSeconds must be a number when provided.");
  }

  const getFileMeta = async (path: string) => {
    const file = bucket.file(path);
    const [exists] = await file.exists();
    if (!exists) return {exists: false, size: 0, contentType: undefined};
    const [metadata] = await file.getMetadata();
    const sizeRaw = metadata.size;
    const size = typeof sizeRaw === "string" ? Number(sizeRaw) : typeof sizeRaw === "number" ? sizeRaw : 0;
    return {
      exists: true,
      size: Number.isFinite(size) ? size : 0,
      contentType: typeof metadata.contentType === "string" ? metadata.contentType : undefined,
    };
  };

  return submitStoryInviteReadingCore(
    db, getFileMeta, parentUid, voiceId, syntheticUid, Date.now(), readingId, mimeType, duration,
  );
});
