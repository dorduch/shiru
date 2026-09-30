import type {Firestore} from "firebase-admin/firestore";
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import type {ApprovalStatus} from "./inviteRedeem";

export type RelativeReadingDecision = "approve" | "reject";

export type RelativeReadingDoc = {
  status: ApprovalStatus;
  storagePath: string;
  mimeType?: string;
  name?: string;
  relationship?: string;
  voiceId?: string;
  durationSeconds?: number | null;
  byteSize?: number;
};

const SIGNED_URL_TTL_MS = 60 * 60 * 1000; // 1h — preview + import window

function assertReadingId(readingId: unknown): asserts readingId is string {
  if (typeof readingId !== "string" || !/^[a-f0-9]{16,64}$/i.test(readingId)) {
    throw new HttpsError("invalid-argument", "readingId is required.");
  }
}

/**
 * Mints a short-lived signed read URL for a relative reading the parent owns.
 * Allowed while pending (preview) or approved (re-download / idempotent import).
 * Rejected readings never get a URL — rejected audio must not enter the library.
 */
export async function getRelativeReadingAudioUrlCore(
  db: Firestore,
  getSignedUrl: (storagePath: string, expiresAt: Date) => Promise<string>,
  parentUid: string,
  readingId: string,
  nowMillis: number,
): Promise<{
  readingId: string;
  downloadUrl: string;
  mimeType: string;
  status: ApprovalStatus;
  name: string;
  relationship: string;
  durationSeconds: number | null;
}> {
  assertReadingId(readingId);
  const snap = await db.doc(`users/${parentUid}/relativeReadings/${readingId}`).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Reading not found.");
  }
  const data = snap.data() as RelativeReadingDoc;
  const status: ApprovalStatus =
    data.status === "approved" || data.status === "rejected" ? data.status : "pending";
  if (status === "rejected") {
    throw new HttpsError("failed-precondition", "This reading was not approved.");
  }
  if (typeof data.storagePath !== "string" || data.storagePath.length === 0) {
    throw new HttpsError("failed-precondition", "Reading audio is unavailable.");
  }

  const expiresAt = new Date(nowMillis + SIGNED_URL_TTL_MS);
  const downloadUrl = await getSignedUrl(data.storagePath, expiresAt);
  return {
    readingId,
    downloadUrl,
    mimeType: typeof data.mimeType === "string" ? data.mimeType : "audio/mp4",
    status,
    name: typeof data.name === "string" ? data.name : "",
    relationship: typeof data.relationship === "string" ? data.relationship : "",
    durationSeconds: typeof data.durationSeconds === "number" ? data.durationSeconds : null,
  };
}

/**
 * Parent approve / reject for a relative reading.
 * - approve: pending→approved (idempotent if already approved); returns signed URL for library import
 * - reject: pending→rejected (idempotent if already rejected); never returns audio
 * Rejected audio must never import; approved→reject and rejected→approve are blocked.
 */
export async function decideRelativeReadingCore(
  db: Firestore,
  getSignedUrl: (storagePath: string, expiresAt: Date) => Promise<string>,
  parentUid: string,
  readingId: string,
  decision: RelativeReadingDecision,
  nowMillis: number,
): Promise<{
  readingId: string;
  status: ApprovalStatus;
  downloadUrl: string | null;
  mimeType: string | null;
  name: string;
  relationship: string;
  durationSeconds: number | null;
}> {
  assertReadingId(readingId);
  if (decision !== "approve" && decision !== "reject") {
    throw new HttpsError("invalid-argument", "decision must be approve or reject.");
  }

  const readingRef = db.doc(`users/${parentUid}/relativeReadings/${readingId}`);

  type TxResult =
    | {ok: true; data: RelativeReadingDoc; status: ApprovalStatus; alreadyDecided: boolean}
    | {ok: false; code: "not-found" | "conflict"; message: string};

  const txResult: TxResult = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(readingRef);
    if (!snap.exists) {
      return {ok: false, code: "not-found", message: "Reading not found."};
    }
    const data = snap.data() as RelativeReadingDoc;
    const current: ApprovalStatus =
      data.status === "approved" || data.status === "rejected" ? data.status : "pending";

    if (decision === "approve") {
      if (current === "rejected") {
        return {ok: false, code: "conflict", message: "This reading was not approved."};
      }
      if (current === "pending") {
        transaction.update(readingRef, {
          status: "approved",
          decidedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {ok: true, data, status: "approved", alreadyDecided: false};
      }
      return {ok: true, data, status: "approved", alreadyDecided: true};
    }

    // reject
    if (current === "approved") {
      return {ok: false, code: "conflict", message: "This reading was already approved."};
    }
    if (current === "pending") {
      transaction.update(readingRef, {
        status: "rejected",
        decidedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {ok: true, data, status: "rejected", alreadyDecided: false};
    }
    return {ok: true, data, status: "rejected", alreadyDecided: true};
  });

  if (!txResult.ok) {
    throw new HttpsError(txResult.code === "not-found" ? "not-found" : "failed-precondition", txResult.message);
  }

  const {data, status} = txResult;
  const name = typeof data.name === "string" ? data.name : "";
  const relationship = typeof data.relationship === "string" ? data.relationship : "";
  const durationSeconds = typeof data.durationSeconds === "number" ? data.durationSeconds : null;
  const mimeType = typeof data.mimeType === "string" ? data.mimeType : null;

  if (status === "rejected") {
    return {
      readingId,
      status,
      downloadUrl: null,
      mimeType: null,
      name,
      relationship,
      durationSeconds,
    };
  }

  if (typeof data.storagePath !== "string" || data.storagePath.length === 0) {
    throw new HttpsError("failed-precondition", "Reading audio is unavailable.");
  }
  const expiresAt = new Date(nowMillis + SIGNED_URL_TTL_MS);
  const downloadUrl = await getSignedUrl(data.storagePath, expiresAt);
  return {
    readingId,
    status: "approved",
    downloadUrl,
    mimeType: mimeType ?? "audio/mp4",
    name,
    relationship,
    durationSeconds,
  };
}
