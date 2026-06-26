import {createHash} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {getAuth} from "firebase-admin/auth";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {
  StoryRequest, parseFamilyVoiceId, safetyPassed, utcQuotaDay, validateStoryRequest, wordCountFor,
} from "./domain";

initializeApp();
const db = getFirestore();
const bucket = getStorage().bucket();

const anthropicKey = defineSecret("ANTHROPIC_API_KEY");
const elevenLabsKey = defineSecret("ELEVENLABS_API_KEY");
const wallyVoice = defineSecret("ELEVENLABS_VOICE_WALLY");
const fernVoice = defineSecret("ELEVENLABS_VOICE_FERN");
const rayVoice = defineSecret("ELEVENLABS_VOICE_RAY");

function requireTrusted(request: {auth?: unknown; app?: unknown}): asserts request is {auth: {uid: string; token: Record<string, unknown>}; app: unknown} {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  if (!request.app) throw new HttpsError("failed-precondition", "App Check is required.");
}

async function isFamilyVoiceEnabled(): Promise<boolean> {
  const doc = await db.doc("storytimeConfig/familyVoice").get();
  return doc.data()?.enabled !== false;
}

// ---------------------------------------------------------------------------
// Voice consent & cloning
// ---------------------------------------------------------------------------

export const createVoiceConsent = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const data = request.data as Record<string, unknown>;
  const name = data?.name;
  const relationship = data?.relationship;
  const subjectLiving = data?.subjectLiving;
  if (typeof name !== "string" || name.trim().length === 0 || name.length > 60) {
    throw new HttpsError("invalid-argument", "name must be a non-empty string of at most 60 characters.");
  }
  if (typeof relationship !== "string" || relationship.trim().length === 0) {
    throw new HttpsError("invalid-argument", "relationship is required.");
  }
  if (typeof subjectLiving !== "boolean") {
    throw new HttpsError("invalid-argument", "subjectLiving must be a boolean.");
  }

  const uid = request.auth.uid;
  const voiceId = createHash("sha256")
    .update(`${uid}:voice:${crypto.randomUUID()}`)
    .digest("hex")
    .slice(0, 32);

  await db.doc(`users/${uid}/voices/${voiceId}`).set({
    name,
    relationship,
    subjectLiving,
    consent: {
      agreedByUid: uid,
      agreedAt: FieldValue.serverTimestamp(),
      relationship,
      subjectLiving,
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

  const enabled = await isFamilyVoiceEnabled();
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
  if (freshData.providerVoiceId) return;

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
      // Copy into a tightly-fit Uint8Array so only this sample's bytes are sent; Buffer.buffer can over-read a pooled allocation.
      form.append("files", new Blob([new Uint8Array(sampleBuffers[i])], {type: "audio/mp4"}), `sample_${i}.m4a`);
    }

    const elResponse = await fetch("https://api.elevenlabs.io/v1/voices/add", {
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

    // Write providerVoiceId BEFORE flipping to ready (idempotency guard for retries)
    await voiceRef.update({providerVoiceId, updatedAt: FieldValue.serverTimestamp()});
    await voiceRef.update({status: "ready", updatedAt: FieldValue.serverTimestamp()});
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
    const elResponse = await fetch(`https://api.elevenlabs.io/v1/voices/${providerVoiceId}`, {
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

// ---------------------------------------------------------------------------
// Story creation & processing
// ---------------------------------------------------------------------------

export const createStoryJob = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const input = validateStoryRequest(request.data);
  if (!input) throw new HttpsError("invalid-argument", "Invalid story choices.");

  const uid = request.auth.uid;

  // Family voice entitlement + readiness check
  const familyVoiceId = parseFamilyVoiceId(input.narratorKey);
  if (familyVoiceId !== null) {
    const enabled = await isFamilyVoiceEnabled();
    if (!enabled) throw new HttpsError("invalid-argument", "Invalid story choices.");
    const voiceSnap = await db.doc(`users/${uid}/voices/${familyVoiceId}`).get();
    if (!voiceSnap.exists || voiceSnap.data()?.status !== "ready") {
      throw new HttpsError("invalid-argument", "Invalid story choices.");
    }
  }

  const config = (await db.doc("storytimeConfig/generation").get()).data() ?? {};
  if (config.enabled === false) throw new HttpsError("unavailable", "Story making is resting right now.");
  // Plan default is 10/day; key is `dailyQuota` (legacy `dailyLimit` kept as fallback).
  const dailyLimit = typeof config.dailyQuota === "number" ? config.dailyQuota :
    typeof config.dailyLimit === "number" ? config.dailyLimit : 10;
  const day = utcQuotaDay();
  const jobId = createHash("sha256").update(`${uid}:${input.idempotencyKey}`).digest("hex").slice(0, 32);
  const jobRef = db.doc(`users/${uid}/storyJobs/${jobId}`);
  const usageRef = db.doc(`users/${uid}/generationUsage/${day}`);

  return db.runTransaction(async (transaction) => {
    const [existingJob, usage] = await Promise.all([
      transaction.get(jobRef), transaction.get(usageRef),
    ]);
    if (existingJob.exists) {
      const data = existingJob.data()!;
      return {jobId, remaining: data.remaining ?? 0};
    }
    const reserved = (usage.data()?.reserved as number | undefined) ?? 0;
    if (reserved >= dailyLimit) throw new HttpsError("resource-exhausted", "daily-limit");
    const remaining = dailyLimit - reserved - 1;
    transaction.set(usageRef, {reserved: reserved + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    transaction.create(jobRef, {
      ...input, status: "queued", remaining, quotaDay: day,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    return {jobId, remaining};
  });
});

async function anthropicJson(prompt: string, maxTokens: number): Promise<Record<string, unknown>> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": anthropicKey.value(),
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001", max_tokens: maxTokens,
      messages: [{role: "user", content: prompt}],
    }),
  });
  if (!response.ok) throw new Error(`Anthropic ${response.status}`);
  const body = await response.json() as {content: Array<{type: string; text?: string}>};
  const text = body.content.find((item) => item.type === "text")?.text;
  if (!text) throw new Error("Anthropic returned no text");
  const json = text.match(/\{[\s\S]*\}/)?.[0];
  if (!json) throw new Error("Anthropic returned invalid JSON");
  return JSON.parse(json) as Record<string, unknown>;
}

function storyPrompt(input: StoryRequest, retry: boolean): string {
  return `Write an original English children's audio story of about ${wordCountFor(input.ageBand)} words.
Character: ${input.character}. Scene: ${input.scene}. Theme: ${input.theme}. Plot: ${input.plot}.
The listener is in age band ${input.ageBand}. Keep conflict gentle and emotionally safe. No graphic danger,
weapons, death, abuse, hate, romance, substances, self-harm, frightening imagery, brands, or requests to buy.
${retry ? "The previous result failed a child-safety review. Make this version calmer and safer." : ""}
Return only JSON: {"title":"...","story":"..."}.`;
}

async function createSafeStory(
  input: StoryRequest,
  onChecking: () => Promise<void>,
): Promise<{title: string; story: string}> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const generated = await anthropicJson(storyPrompt(input, attempt > 0), 5000);
    if (typeof generated.title !== "string" || typeof generated.story !== "string") continue;
    await onChecking();
    const review = await anthropicJson(
      `Review this children's story for sexual content, graphic or intense violence, self-harm, abuse,
hate, substances, unsafe instructions, frightening intensity, or commercial persuasion.
Return only JSON: {"safe":true|false,"concerns":["..."]}. Story: ${generated.story}`,
      500,
    );
    if (safetyPassed(review)) return {title: generated.title.slice(0, 100), story: generated.story};
  }
  throw new Error("safety-rejected");
}

async function synthesize(text: string, resolvedVoiceId: string): Promise<Buffer> {
  const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${resolvedVoiceId}`, {
    method: "POST",
    headers: {"xi-api-key": elevenLabsKey.value(), "content-type": "application/json", accept: "audio/mpeg"},
    body: JSON.stringify({text, model_id: "eleven_multilingual_v2", voice_settings: {stability: 0.55, similarity_boost: 0.75}}),
  });
  if (!response.ok) throw new Error(`ElevenLabs ${response.status}`);
  return Buffer.from(await response.arrayBuffer());
}

export const processStoryJob = onDocumentCreated({
  document: "users/{uid}/storyJobs/{jobId}", timeoutSeconds: 540, memory: "1GiB",
  secrets: [anthropicKey, elevenLabsKey, wallyVoice, fernVoice, rayVoice], retry: true,
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data() as StoryRequest & {status: string; quotaDay: string};
  if (data.status !== "queued") return;
  const ref = snapshot.ref;
  const uid = event.params.uid;
  const started = Date.now();
  try {
    await ref.update({status: "writing", updatedAt: FieldValue.serverTimestamp()});
    const story = await createSafeStory(data, async () => {
      await ref.update({
        status: "checking",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await ref.update({status: "narrating", updatedAt: FieldValue.serverTimestamp()});

    // Resolve voiceId: built-in narrators or family voice
    let resolvedVoiceId: string;
    const familyVoiceId = parseFamilyVoiceId(data.narratorKey);
    if (familyVoiceId !== null) {
      const voiceSnap = await db.doc(`users/${uid}/voices/${familyVoiceId}`).get();
      const providerVoiceId = voiceSnap.data()?.providerVoiceId as string | undefined;
      if (!providerVoiceId) throw new Error("family-voice-not-ready");
      resolvedVoiceId = providerVoiceId;
    } else {
      const builtinMap: Record<string, string> = {
        wizardWally: wallyVoice.value(),
        fairyFern: fernVoice.value(),
        roboRay: rayVoice.value(),
      };
      const voiceId = builtinMap[data.narratorKey as string];
      if (!voiceId) throw new Error(`Unknown narrator: ${data.narratorKey}`);
      resolvedVoiceId = voiceId;
    }

    const audio = await synthesize(story.story, resolvedVoiceId);
    const objectPath = `story-jobs/${uid}/${event.params.jobId}.mp3`;
    const file = bucket.file(objectPath);
    await file.save(audio, {contentType: "audio/mpeg", resumable: false});
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const [downloadUrl] = await file.getSignedUrl({action: "read", expires: expiresAt});
    await ref.update({
      status: "ready", title: story.title, story: story.story, downloadUrl, storagePath: objectPath,
      expiresAt: Timestamp.fromDate(expiresAt), updatedAt: FieldValue.serverTimestamp(),
    });
    logger.info("story_job_ready", {durationMs: Date.now() - started});
  } catch (error) {
    const errorCode = error instanceof Error && error.message === "safety-rejected" ? "safety" : "provider";
    await db.runTransaction(async (transaction) => {
      const usageRef = db.doc(`users/${uid}/generationUsage/${data.quotaDay}`);
      const usage = await transaction.get(usageRef);
      const reserved = Math.max(0, ((usage.data()?.reserved as number | undefined) ?? 1) - 1);
      transaction.set(usageRef, {reserved, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      transaction.update(ref, {status: "failed", errorCode, updatedAt: FieldValue.serverTimestamp()});
    });
    logger.error("story_job_failed", {errorCode, durationMs: Date.now() - started});
  }
});

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
      const elResponse = await fetch(`https://api.elevenlabs.io/v1/voices/${providerVoiceId}`, {
        method: "DELETE",
        headers: {"xi-api-key": elevenLabsKey.value()},
      });
      if (!elResponse.ok && elResponse.status !== 404) {
        logger.warn("delete_account_elevenlabs_error", {uid, providerVoiceId, status: elResponse.status});
      }
    }
  }));
  await bucket.deleteFiles({prefix: `voice-samples/${uid}/`});

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
