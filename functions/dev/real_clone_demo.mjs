// REAL end-to-end family-voice demo against the emulators + the live ElevenLabs API.
// 1. uploads a real voice sample, runs it through processVoiceClone (real clone)
// 2. narrates a bedtime line in the cloned voice via ElevenLabs TTS
import admin from "firebase-admin";
import {readFileSync, writeFileSync} from "node:fs";

process.env.FIRESTORE_EMULATOR_HOST ||= "127.0.0.1:8080";
process.env.STORAGE_EMULATOR_HOST ||= "http://127.0.0.1:9199";

admin.initializeApp({projectId: "shiru-bcdd2", storageBucket: "shiru-bcdd2.appspot.com"});
const db = admin.firestore();
const bucket = admin.storage().bucket();
const FV = admin.firestore.FieldValue;

const uid = "demo-real-1";
const voiceId = "demo-real-voice-1";
const samplePath = `voice-samples/${uid}/${voiceId}/0.m4a`;
const ref = db.doc(`users/${uid}/voices/${voiceId}`);
const localSample = "/tmp/voice_sample.m4a";

// read the real key from .secret.local for the narration-proof step (not printed)
const key = readFileSync(new URL("../.secret.local", import.meta.url), "utf8")
  .split("\n").find((l) => l.startsWith("ELEVENLABS_API_KEY="))?.split("=").slice(1).join("=").trim();
if (!key) throw new Error("ELEVENLABS_API_KEY not found in functions/.secret.local");

try {
  await ref.delete().catch(() => {});
  await bucket.file(samplePath).delete().catch(() => {});

  console.log("1. upload REAL voice sample to storage emulator");
  await bucket.upload(localSample, {destination: samplePath, metadata: {contentType: "audio/mp4"}});

  console.log("2. create consent doc + flip to queued (fires processVoiceClone -> REAL ElevenLabs clone)");
  await ref.set({
    name: "Grandma Sam", relationship: "grandparent", subjectLiving: true,
    consent: {agreedByUid: uid, agreedAt: FV.serverTimestamp(), relationship: "grandparent", subjectLiving: true},
    status: "consented", samplePaths: [], createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
  });
  await ref.update({status: "queued", samplePaths: [samplePath], updatedAt: FV.serverTimestamp()});

  console.log("3. waiting for real clone (this calls api.elevenlabs.io, can take ~10-40s)...");
  let data;
  for (let i = 0; i < 120; i++) {
    await new Promise((r) => setTimeout(r, 1000));
    data = (await ref.get()).data();
    process.stdout.write(`\r   status=${data?.status}            `);
    if (data && ["ready", "failed"].includes(data.status)) break;
  }
  console.log(`\n   -> status=${data?.status} providerVoiceId=${data?.providerVoiceId ?? "-"} errorCode=${data?.errorCode ?? "-"}`);

  if (data?.status !== "ready" || !data?.providerVoiceId) {
    console.log("\nCLONE FAILED — see emulator log for the ElevenLabs error.");
    process.exit(1);
  }

  console.log("\n4. narrate a bedtime line in the CLONED voice (ElevenLabs TTS)...");
  const text = "Goodnight, my darling. The stars are out, the moon is bright, and it is time for sweet dreams. I love you all the way to the moon and back.";
  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${data.providerVoiceId}`, {
    method: "POST",
    headers: {"xi-api-key": key, "content-type": "application/json", accept: "audio/mpeg"},
    body: JSON.stringify({text, model_id: "eleven_multilingual_v2", voice_settings: {stability: 0.55, similarity_boost: 0.75}}),
  });
  if (!res.ok) {
    console.log(`   TTS failed: ${res.status} ${await res.text().catch(() => "")}`);
    process.exit(1);
  }
  const audio = Buffer.from(await res.arrayBuffer());
  writeFileSync("/tmp/cloned_narration.mp3", audio);
  console.log(`   wrote /tmp/cloned_narration.mp3 (${audio.length} bytes) — narrated in the cloned voice.`);
  console.log("\nRESULT: REAL CLONE + NARRATION OK");
} catch (e) {
  console.error("DEMO ERROR:", e);
  process.exit(1);
}
process.exit(0);
