import {createHash, randomBytes} from "node:crypto";
import {FieldValue} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import {contentTypeForSamplePath, isValidInviteToken, validateCreateInviteRequest} from "./domain";
import {flipVoiceToQueued} from "./voiceClone";
import {createVoiceInviteCore} from "./voiceInvite";
import {INVALID_REDEEM_MESSAGE, redeemVoiceInviteCore} from "./inviteRedeem";
import {db, bucket, ELEVENLABS_BASE, INVITE_HOST, elevenLabsKey, requireTrusted} from "./cfShared";

export const createVoiceConsent = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const data = request.data as Record<string, unknown>;
  const name = data?.name;
  const relationship = data?.relationship;
  if (typeof name !== "string" || name.trim().length === 0 || name.length > 60) {
    throw new HttpsError("invalid-argument", "name must be a non-empty string of at most 60 characters.");
  }
  if (typeof relationship !== "string" || relationship.trim().length === 0) {
    throw new HttpsError("invalid-argument", "relationship is required.");
  }

  const uid = request.auth.uid;
  const voiceId = createHash("sha256")
    .update(`${uid}:voice:${crypto.randomUUID()}`)
    .digest("hex")
    .slice(0, 32);

  await db.doc(`users/${uid}/voices/${voiceId}`).set({
    name,
    relationship,
    consent: {
      agreedByUid: uid,
      agreedAt: FieldValue.serverTimestamp(),
      relationship,
    },
    status: "consented",
    samplePaths: [],
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {voiceId};
});

export const submitVoiceClone = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const uid = request.auth.uid;
  const data = request.data as Record<string, unknown>;
  const voiceId = data?.voiceId;
  const samplePaths = data?.samplePaths;

  if (typeof voiceId !== "string" || voiceId.length === 0) {
    throw new HttpsError("invalid-argument", "voiceId is required.");
  }
  if (!Array.isArray(samplePaths) || samplePaths.length === 0) {
    throw new HttpsError("invalid-argument", "samplePaths must be a non-empty array.");
  }
  const expectedPrefix = `voice-samples/${uid}/${voiceId}/`;
  for (const p of samplePaths) {
    if (typeof p !== "string" || !p.startsWith(expectedPrefix)) {
      throw new HttpsError("invalid-argument", `Each samplePath must start with ${expectedPrefix}`);
    }
  }

  await flipVoiceToQueued(db, uid, voiceId, samplePaths);

  return {ok: true};
});

export const processVoiceClone = onDocumentUpdated({
  document: "users/{uid}/voices/{voiceId}",
  timeoutSeconds: 300,
  memory: "1GiB",
  secrets: [elevenLabsKey],
  retry: true,
}, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  // Only act when transitioning into "queued"
  if (before.status === "queued" || after.status !== "queued") return;

  const uid = event.params.uid;
  const voiceId = event.params.voiceId;
  const voiceRef = db.doc(`users/${uid}/voices/${voiceId}`);
  const started = Date.now();

  // Idempotency check: re-read to avoid duplicate ElevenLabs voice creation
  const fresh = await voiceRef.get();
  if (!fresh.exists) return;
  const freshData = fresh.data()!;
  // Already cloned on a prior run (retry after a crash post-clone): don't re-call
  // ElevenLabs, but make sure we still finish the transition to "ready" so the doc
  // can't get stuck at "cloning" forever.
  if (freshData.providerVoiceId) {
    if (freshData.status !== "ready") {
      await voiceRef.update({status: "ready", updatedAt: FieldValue.serverTimestamp()});
    }
    return;
  }

  try {
    await voiceRef.update({status: "cloning", updatedAt: FieldValue.serverTimestamp()});

    const samplePaths: string[] = freshData.samplePaths ?? [];
    if (samplePaths.length === 0) {
      throw Object.assign(new Error("no-samples"), {errorCode: "no-samples"});
    }

    // Download sample files from Storage
    const sampleBuffers: Buffer[] = await Promise.all(
      samplePaths.map(async (p) => {
        const [contents] = await bucket.file(p).download();
        return contents;
      }),
    );

    // Call ElevenLabs add-voice using Node 22 native FormData/Blob
    const form = new FormData();
    form.append("name", freshData.name as string);
    for (let i = 0; i < sampleBuffers.length; i++) {
      const {contentType, ext} = contentTypeForSamplePath(samplePaths[i]);
      // Copy into a tightly-fit Uint8Array so only this sample's bytes are sent; Buffer.buffer can over-read a pooled allocation.
      form.append("files", new Blob([new Uint8Array(sampleBuffers[i])], {type: contentType}), `sample_${i}.${ext}`);
    }

    const elResponse = await fetch(`${ELEVENLABS_BASE}/v1/voices/add`, {
      method: "POST",
      headers: {"xi-api-key": elevenLabsKey.value()},
      body: form,
    });

    if (!elResponse.ok) {
      const errText = await elResponse.text().catch(() => "");
      throw new Error(`ElevenLabs ${elResponse.status}: ${errText}`);
    }

    const elBody = await elResponse.json() as {voice_id: string};
    const providerVoiceId = elBody.voice_id;

    // Single atomic write: providerVoiceId + ready together, so a crash can never
    // leave providerVoiceId set without the status reaching "ready".
    await voiceRef.update({providerVoiceId, status: "ready", updatedAt: FieldValue.serverTimestamp()});
    logger.info("voice_clone_ready", {uid, voiceId, durationMs: Date.now() - started});
  } catch (error) {
    const errorCode = error instanceof Error && (error as {errorCode?: string}).errorCode === "no-samples"
      ? "no-samples"
      : "provider";
    await voiceRef.update({status: "failed", errorCode, updatedAt: FieldValue.serverTimestamp()});
    logger.error("voice_clone_failed", {uid, voiceId, errorCode, durationMs: Date.now() - started, error: String(error)});
  }
});

export const deleteVoice = onCall({enforceAppCheck: true, secrets: [elevenLabsKey]}, async (request) => {
  requireTrusted(request);
  const uid = request.auth.uid;
  const data = request.data as Record<string, unknown>;
  const voiceId = data?.voiceId;
  if (typeof voiceId !== "string" || voiceId.length === 0) {
    throw new HttpsError("invalid-argument", "voiceId is required.");
  }

  const voiceRef = db.doc(`users/${uid}/voices/${voiceId}`);
  const voiceSnap = await voiceRef.get();
  if (!voiceSnap.exists) throw new HttpsError("not-found", "Voice not found.");

  const voiceData = voiceSnap.data()!;
  const providerVoiceId = voiceData.providerVoiceId as string | undefined;

  // Delete from ElevenLabs if a provider voice exists
  if (providerVoiceId) {
    const elResponse = await fetch(`${ELEVENLABS_BASE}/v1/voices/${providerVoiceId}`, {
      method: "DELETE",
      headers: {"xi-api-key": elevenLabsKey.value()},
    });
    if (!elResponse.ok && elResponse.status !== 404) {
      logger.warn("voice_delete_elevenlabs_error", {uid, voiceId, providerVoiceId, status: elResponse.status});
    }
  }

  // Delete Storage samples
  await bucket.deleteFiles({prefix: `voice-samples/${uid}/${voiceId}/`});

  // Delete Firestore doc
  await voiceRef.delete();

  return {ok: true};
});

export const createVoiceInvite = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const input = validateCreateInviteRequest(request.data);
  if (!input) throw new HttpsError("invalid-argument", "voiceId is required.");

  const uid = request.auth.uid;
  const token = randomBytes(32).toString("base64url");
  const result = await createVoiceInviteCore(db, uid, input.voiceId, token, Date.now(), INVITE_HOST);

  return {url: result.url, expiresAt: result.expiresAt.toDate().toISOString()};
});

// `redeemVoiceInvite` deliberately has NO prior auth requirement (that's the
// point — it's how an invitee with no account gets one) and does not enforce
// App Check, since the static invite web page signs in via custom token, not
// an App-Check-attested native/web client. All request-shape validation and
// the generic not-valid error live here; the security-critical branching
// (not-found / wrong-status / expired, all identical) lives in
// `redeemVoiceInviteCore`.
export const redeemVoiceInvite = onCall({enforceAppCheck: false}, async (request) => {
  const data = request.data as Record<string, unknown>;
  const token = data?.token;
  if (!isValidInviteToken(token)) {
    throw new HttpsError("failed-precondition", INVALID_REDEEM_MESSAGE);
  }
  return redeemVoiceInviteCore(db, token, Date.now(), (uid, claims) => getAuth().createCustomToken(uid, claims));
});
