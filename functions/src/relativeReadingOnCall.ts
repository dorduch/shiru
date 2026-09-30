import {HttpsError, onCall} from "firebase-functions/v2/https";
import {bucket, db, requireTrusted} from "./cfShared";
import {
  decideRelativeReadingCore,
  getRelativeReadingAudioUrlCore,
} from "./relativeReadingDecide";

// Parent-auth + App Check. Short-lived signed URL for preview (pending) or
// re-download (approved). Rejected readings never get a URL.
export const getRelativeReadingAudioUrl = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const readingId = (request.data as Record<string, unknown> | undefined)?.readingId;
  if (typeof readingId !== "string") {
    throw new HttpsError("invalid-argument", "readingId is required.");
  }
  const getSignedUrl = async (storagePath: string, expiresAt: Date) => {
    const [url] = await bucket.file(storagePath).getSignedUrl({action: "read", expires: expiresAt});
    return url;
  };
  return getRelativeReadingAudioUrlCore(db, getSignedUrl, request.auth.uid, readingId, Date.now());
});

// Parent-auth + App Check. Approve → signed URL for library import; reject →
// status flip only. Idempotent on double-approve / double-reject.
export const decideRelativeReading = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const data = (request.data as Record<string, unknown> | undefined) ?? {};
  const readingId = data.readingId;
  const decision = data.decision;
  if (typeof readingId !== "string") {
    throw new HttpsError("invalid-argument", "readingId is required.");
  }
  if (decision !== "approve" && decision !== "reject") {
    throw new HttpsError("invalid-argument", "decision must be approve or reject.");
  }
  const getSignedUrl = async (storagePath: string, expiresAt: Date) => {
    const [url] = await bucket.file(storagePath).getSignedUrl({action: "read", expires: expiresAt});
    return url;
  };
  return decideRelativeReadingCore(
    db, getSignedUrl, request.auth.uid, readingId, decision, Date.now(),
  );
});
