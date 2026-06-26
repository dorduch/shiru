// Drives the M4 voice-clone trigger pipeline against the Firebase emulators.
// Simulates what the client does after createVoiceConsent + sample upload:
// upload a sample, create the consented doc, flip to "queued", then observe
// processVoiceClone download the sample, POST the mock ElevenLabs, and reach ready.
import admin from "firebase-admin";

process.env.FIRESTORE_EMULATOR_HOST ||= "127.0.0.1:8080";
process.env.STORAGE_EMULATOR_HOST ||= "http://127.0.0.1:9199";

admin.initializeApp({projectId: "shiru-bcdd2", storageBucket: "shiru-bcdd2.appspot.com"});
const db = admin.firestore();
const bucket = admin.storage().bucket();
const FV = admin.firestore.FieldValue;

const uid = "harness-uid-1";
const voiceId = "harness-voice-1";
const samplePath = `voice-samples/${uid}/${voiceId}/0.m4a`;
const ref = db.doc(`users/${uid}/voices/${voiceId}`);

const ok = (b) => (b ? "PASS" : "FAIL");
let allPass = true;
const check = (name, b) => { allPass = allPass && b; console.log(`  [${ok(b)}] ${name}`); };

try {
  // clean slate
  await ref.delete().catch(() => {});
  await bucket.file(samplePath).delete().catch(() => {});

  console.log("1. upload sample to storage emulator");
  await bucket.file(samplePath).save(Buffer.from("FAKE_AUDIO_BYTES_for_grandma_voice_sample"), {contentType: "audio/mp4"});

  console.log("2. create consented voice doc (mirrors createVoiceConsent)");
  await ref.set({
    name: "Grandma", relationship: "grandparent", subjectLiving: true,
    consent: {agreedByUid: uid, agreedAt: FV.serverTimestamp(), relationship: "grandparent", subjectLiving: true},
    status: "consented", samplePaths: [], createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
  });

  console.log("3. flip to queued with samplePaths (mirrors submitVoiceClone) -> should fire processVoiceClone");
  await ref.update({status: "queued", samplePaths: [samplePath], updatedAt: FV.serverTimestamp()});

  console.log("4. poll for terminal status...");
  let data;
  for (let i = 0; i < 60; i++) {
    await new Promise((r) => setTimeout(r, 500));
    const snap = await ref.get();
    data = snap.data();
    if (data && ["ready", "failed"].includes(data.status)) break;
  }

  console.log("\nfinal doc:", JSON.stringify({status: data?.status, providerVoiceId: data?.providerVoiceId, errorCode: data?.errorCode}));
  console.log("\nAssertions:");
  check("status reached 'ready'", data?.status === "ready");
  check("providerVoiceId set by mock", typeof data?.providerVoiceId === "string" && data.providerVoiceId.startsWith("mock_voice_"));
  check("no errorCode", !data?.errorCode);
} catch (e) {
  console.error("HARNESS ERROR:", e);
  allPass = false;
}

console.log(`\nRESULT: ${allPass ? "ALL PASS" : "FAILURES"}`);
process.exit(allPass ? 0 : 1);
