# Local e2e verification — M4 voice-clone trigger pipeline

Drives `processVoiceClone` against the Firebase Emulator Suite with a mocked
ElevenLabs API (no key, no cost, no prod). Verifies: Storage sample download,
multipart `FormData` POST, the `consented→queued→cloning→ready` state machine,
and the atomic `providerVoiceId`+`ready` write.

## Run

```sh
cd functions

# 1. mock ElevenLabs (returns a fake voice_id, accepts DELETE)
node dev/elevenlabs_mock.cjs &        # listens on 127.0.0.1:4999

# 2. emulators — note the env workarounds (see gotchas below)
ELEVENLABS_BASE_URL=http://127.0.0.1:4999 \
ELEVENLABS_API_KEY=dummy \
GCLOUD_PROJECT=shiru-bcdd2 \
NO_UPDATE_NOTIFIER=1 \
XDG_CONFIG_HOME=/tmp/fbconfig \
FIREBASE_EMULATORS_PATH=/tmp/fbemulators \
  ./node_modules/.bin/firebase emulators:start \
    --only functions,firestore,storage,auth --project shiru-bcdd2 &

# 3. harness (must run from functions/ so ESM resolves node_modules)
node dev/voice_clone_harness.mjs      # prints PASS/FAIL assertions
```

Expected: `RESULT: ALL PASS`, and the mock logs a `POST /v1/voices/add (... bytes multipart received)`
plus one `file part: filename=... contentType=...` line per sample. The harness sends a mixed
`sample_0.m4a` (audio/mp4) + `sample_1.webm` (audio/webm) set — confirm both are labeled correctly
(no `MISMATCH` lines) to verify the per-sample content-type fix in `processVoiceClone`.

### Live webm smoke test (spends ElevenLabs credits — human/Task 9 only)

Not run as part of this task. To verify ElevenLabs' `/v1/voices/add` actually accepts
`audio/webm` (the plan's "UNVERIFIED assumption"), record or obtain a short real `.webm`
sample, then from `functions/`:

```sh
SAMPLE_FILE=/tmp/voice_sample.webm SAMPLE_EXT=webm node dev/real_clone_demo.mjs
```

This reuses the existing `.m4a` live-demo path (`node dev/real_clone_demo.mjs` with no env
override) but points it at a webm fixture instead, so it clones with a real webm sample against
the real API and reports success/failure.

## Env gotchas discovered on this machine

- `~/.cache/firebase` is **root-owned** → emulator jar download fails with EACCES.
  `FIREBASE_EMULATORS_PATH=/tmp/...` relocates the jar cache to a writable dir.
- firebase-tools' update-notifier choked on `~/.config` → `NO_UPDATE_NOTIFIER=1`
  (and a fresh `XDG_CONFIG_HOME`) avoids it.
- **Bucket name:** in the emulator, the function's `getStorage().bucket()` default
  resolves to `shiru-bcdd2.appspot.com` (legacy), NOT the app's
  `shiru-bcdd2.firebasestorage.app`. The harness uploads to `appspot.com` so the
  function can find the sample. (No impact in prod, where both resolve consistently.)
- The `ELEVENLABS_BASE_URL` seam (in `src/index.ts`) is the only production-code
  hook used here; it is unset in prod, so prod always hits the real API.

This does NOT exercise the App Check-enforced callables (`createVoiceConsent`,
`submitVoiceClone`, `createStoryJob` family validation) — the emulator can't mint
valid App Check tokens. The harness simulates their Firestore writes directly;
their synchronous validation logic is covered by `src/domain.test.ts` + review.
