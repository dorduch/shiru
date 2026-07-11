import type {Firestore} from "firebase-admin/firestore";
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

/**
 * Whether the family-voice feature is enabled, per `storytimeConfig/familyVoice`.
 * Defaults to enabled (fails open) when the doc/field is absent, matching the
 * behavior this replaced in index.ts.
 */
export async function isFamilyVoiceEnabled(db: Firestore): Promise<boolean> {
  const doc = await db.doc("storytimeConfig/familyVoice").get();
  return doc.data()?.enabled !== false;
}

/**
 * Core status-transition logic behind `submitVoiceClone`: checks the
 * family-voice entitlement, verifies the voice exists and is in a state that
 * can be (re)queued, then flips it to "queued" with the given sample paths.
 *
 * Extracted so both the in-app `submitVoiceClone` callable (App-Check gated)
 * and the future invite-gated web path (`submitVoiceInvite`, Task 4) can
 * share the exact same logic. This is a straight lift of what used to be the
 * back half of `submitVoiceClone` in index.ts — `requireTrusted(request)` and
 * the request.auth / request.data argument parsing stay in each callable
 * wrapper; this helper only starts once uid/voiceId/samplePaths are already
 * validated.
 */
export async function flipVoiceToQueued(
  db: Firestore,
  uid: string,
  voiceId: string,
  samplePaths: string[],
): Promise<void> {
  const enabled = await isFamilyVoiceEnabled(db);
  if (!enabled) throw new HttpsError("failed-precondition", "family-voice-disabled");

  const voiceRef = db.doc(`users/${uid}/voices/${voiceId}`);
  const voiceSnap = await voiceRef.get();
  if (!voiceSnap.exists) throw new HttpsError("not-found", "Voice not found.");
  const voiceData = voiceSnap.data()!;
  if (voiceData.status !== "consented" && voiceData.status !== "failed") {
    throw new HttpsError("failed-precondition", "Voice is not in consented or failed state.");
  }

  await voiceRef.update({
    status: "queued",
    samplePaths,
    updatedAt: FieldValue.serverTimestamp(),
  });
}
