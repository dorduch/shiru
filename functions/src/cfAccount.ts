import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {db, bucket, ELEVENLABS_BASE, elevenLabsKey, requireTrusted} from "./cfShared";

export const confirmStoryImported = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const jobId = request.data?.jobId;
  if (typeof jobId !== "string") throw new HttpsError("invalid-argument", "jobId required");
  const ref = db.doc(`users/${request.auth.uid}/storyJobs/${jobId}`);
  const job = await ref.get();
  if (!job.exists) throw new HttpsError("not-found", "Story job not found");
  const path = job.data()?.storagePath as string | undefined;
  if (path) await bucket.file(path).delete({ignoreNotFound: true});
  await ref.update({imported: true, downloadUrl: FieldValue.delete(), storagePath: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp()});
  return {ok: true};
});

export const joinFamilyVoiceWaitlist = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  await db.doc(`familyVoiceWaitlist/${request.auth.uid}`).set({
    uid: request.auth.uid, email: request.auth.token.email ?? null,
    joinedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  return {ok: true};
});

export const deleteAccountData = onCall({enforceAppCheck: true, secrets: [elevenLabsKey]}, async (request) => {
  requireTrusted(request);
  const uid = request.auth.uid;

  // Purge ElevenLabs voices and voice sample files before recursiveDelete removes the Firestore docs
  const voicesSnap = await db.collection(`users/${uid}/voices`).get();
  await Promise.all(voicesSnap.docs.map(async (voiceDoc) => {
    const providerVoiceId = voiceDoc.data().providerVoiceId as string | undefined;
    if (providerVoiceId) {
      const elResponse = await fetch(`${ELEVENLABS_BASE}/v1/voices/${providerVoiceId}`, {
        method: "DELETE",
        headers: {"xi-api-key": elevenLabsKey.value()},
      });
      if (!elResponse.ok && elResponse.status !== 404) {
        logger.warn("delete_account_elevenlabs_error", {uid, providerVoiceId, status: elResponse.status});
      }
    }
  }));
  await bucket.deleteFiles({prefix: `voice-samples/${uid}/`});
  await bucket.deleteFiles({prefix: `relative-readings/${uid}/`});

  await db.recursiveDelete(db.doc(`users/${uid}`));
  await db.doc(`familyVoiceWaitlist/${uid}`).delete();
  await bucket.deleteFiles({prefix: `story-jobs/${uid}/`});
  await getAuth().deleteUser(uid);
  return {ok: true};
});

export const cleanupExpiredStoryAudio = onSchedule("every 6 hours", async () => {
  const expired = await db.collectionGroup("storyJobs").where("expiresAt", "<=", Timestamp.now()).limit(100).get();
  await Promise.all(expired.docs.map(async (job) => {
    const path = job.data().storagePath as string | undefined;
    if (path) await bucket.file(path).delete({ignoreNotFound: true});
    await job.ref.update({downloadUrl: FieldValue.delete(), storagePath: FieldValue.delete(), expired: true});
  }));
});
