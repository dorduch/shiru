import {createHash} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {getAuth} from "firebase-admin/auth";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {
  StoryRequest, safetyPassed, utcQuotaDay, validateStoryRequest, wordCountFor,
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

export const createStoryJob = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const input = validateStoryRequest(request.data);
  if (!input) throw new HttpsError("invalid-argument", "Invalid story choices.");

  const config = (await db.doc("storytimeConfig/generation").get()).data() ?? {};
  if (config.enabled === false) throw new HttpsError("unavailable", "Story making is resting right now.");
  const dailyLimit = typeof config.dailyLimit === "number" ? config.dailyLimit : 3;
  const uid = request.auth.uid;
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

async function synthesize(text: string, narrator: StoryRequest["narratorKey"]): Promise<Buffer> {
  const voiceId = {wizardWally: wallyVoice.value(), fairyFern: fernVoice.value(), roboRay: rayVoice.value()}[narrator];
  const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
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
    const audio = await synthesize(story.story, data.narratorKey);
    const objectPath = `story-jobs/${event.params.uid}/${event.params.jobId}.mp3`;
    const file = bucket.file(objectPath);
    await file.save(audio, {contentType: "audio/mpeg", resumable: false});
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const [downloadUrl] = await file.getSignedUrl({action: "read", expires: expiresAt});
    await ref.update({
      status: "ready", title: story.title, downloadUrl, storagePath: objectPath,
      expiresAt: Timestamp.fromDate(expiresAt), updatedAt: FieldValue.serverTimestamp(),
    });
    logger.info("story_job_ready", {durationMs: Date.now() - started});
  } catch (error) {
    const errorCode = error instanceof Error && error.message === "safety-rejected" ? "safety" : "provider";
    await db.runTransaction(async (transaction) => {
      const usageRef = db.doc(`users/${event.params.uid}/generationUsage/${data.quotaDay}`);
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

export const deleteAccountData = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  await db.recursiveDelete(db.doc(`users/${request.auth.uid}`));
  await db.doc(`familyVoiceWaitlist/${request.auth.uid}`).delete();
  await bucket.deleteFiles({prefix: `story-jobs/${request.auth.uid}/`});
  await getAuth().deleteUser(request.auth.uid);
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
