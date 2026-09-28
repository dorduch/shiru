import {createHash} from "node:crypto";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import {
  StoryRequest, parseFamilyVoiceId, safetyPassed, utcQuotaDay,
  validateStoryRequest, wordCountFor,
} from "./domain";
import {ElevenLabsAlignment, deriveWordStarts} from "./timing";
import {isFamilyVoiceEnabled} from "./voiceClone";
import {
  db, bucket, ELEVENLABS_BASE, anthropicKey, elevenLabsKey,
  wallyVoice, fernVoice, rayVoice, requireTrusted,
} from "./cfShared";

export const createStoryJob = onCall({enforceAppCheck: true}, async (request) => {
  requireTrusted(request);
  const input = validateStoryRequest(request.data);
  if (!input) throw new HttpsError("invalid-argument", "Invalid story choices.");

  const uid = request.auth.uid;

  // Family voice entitlement + readiness check
  const familyVoiceId = parseFamilyVoiceId(input.narratorKey);
  if (familyVoiceId !== null) {
    const enabled = await isFamilyVoiceEnabled(db);
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
  return `Write an original English children's audio story of about ${wordCountFor(input.ageBand)} words.\nCharacter: ${input.character}. Scene: ${input.scene}. Theme: ${input.theme}. Plot: ${input.plot}.\nThe listener is in age band ${input.ageBand}. Keep conflict gentle and emotionally safe. No graphic danger,\nweapons, death, abuse, hate, romance, substances, self-harm, frightening imagery, brands, or requests to buy.\n${retry ? "The previous result failed a child-safety review. Make this version calmer and safer." : ""}\nReturn only JSON: {"title":"...","story":"..."}.`;
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
      `Review this children's story for sexual content, graphic or intense violence, self-harm, abuse,\nhate, substances, unsafe instructions, frightening intensity, or commercial persuasion.\nReturn only JSON: {"safe":true|false,"concerns":["..."]}. Story: ${generated.story}`,
      500,
    );
    if (safetyPassed(review)) return {title: generated.title.slice(0, 100), story: generated.story};
  }
  throw new Error("safety-rejected");
}

async function synthesize(text: string, resolvedVoiceId: string): Promise<{audio: Buffer; wordStarts: number[]}> {
  // /with-timestamps returns JSON (audio_base64 + a per-character alignment)
  // instead of a raw audio/mpeg body, so read-along highlighting works for
  // AI-generated stories the same way it already does for the bundled
  // curated ones (see functions/dev/generate_starter_stories.mjs).
  const response = await fetch(`${ELEVENLABS_BASE}/v1/text-to-speech/${resolvedVoiceId}/with-timestamps`, {
    method: "POST",
    headers: {"xi-api-key": elevenLabsKey.value(), "content-type": "application/json"},
    body: JSON.stringify({text, model_id: "eleven_multilingual_v2", voice_settings: {stability: 0.55, similarity_boost: 0.75}}),
  });
  if (!response.ok) throw new Error(`ElevenLabs ${response.status}`);
  const body = await response.json() as {audio_base64?: string; audioBase64?: string; alignment?: ElevenLabsAlignment};
  const audioBase64 = body.audio_base64 ?? body.audioBase64;
  if (!audioBase64) throw new Error("ElevenLabs response missing audio_base64");
  const audio = Buffer.from(audioBase64, "base64");

  // Word timing is a nice-to-have, not a hard requirement: a malformed or
  // missing alignment must never fail the whole story job — the client falls
  // back to a linear-progress estimate when wordStarts is empty.
  let wordStarts: number[] = [];
  try {
    wordStarts = deriveWordStarts(text, body.alignment);
  } catch (error) {
    logger.warn("story_word_timing_derivation_failed", {error: String(error)});
  }
  return {audio, wordStarts};
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

    const {audio, wordStarts} = await synthesize(story.story, resolvedVoiceId);
    const objectPath = `story-jobs/${uid}/${event.params.jobId}.mp3`;
    const file = bucket.file(objectPath);
    await file.save(audio, {contentType: "audio/mpeg", resumable: false});
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const [downloadUrl] = await file.getSignedUrl({action: "read", expires: expiresAt});
    await ref.update({
      status: "ready", title: story.title, story: story.story, downloadUrl, storagePath: objectPath,
      wordStarts, expiresAt: Timestamp.fromDate(expiresAt), updatedAt: FieldValue.serverTimestamp(),
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
    logger.error("story_job_failed", {errorCode, durationMs: Date.now() - started, error: String(error)});
  }
});
