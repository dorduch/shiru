# Firebase setup — run Storytime on an Android device (untethered)

**Goal:** install the app on a physical Android phone and have the full Storytime
flow (story generation **+ family voice cloning**) work without the Mac, the
emulator, or `flutter run` attached.

**Project:** `shiru-bcdd2` · **Functions region:** `us-central1`

> The core app (cards + local audio) is 100% offline and needs none of this.
> Everything below exists only for the Storytime feature, which talks to the
> live `shiru-bcdd2` backend. When you `flutter run` over USB the app uses the
> App Check **debug** provider; once it's a standalone install that path changes,
> which is what most of this checklist is about.

Work top-to-bottom — earlier items gate later ones.

---

## 0. Decide how the build attests (App Check)

Every Storytime callable is `enforceAppCheck: true`. The app must present a valid
App Check token or **all** calls fail with `unauthenticated` / `failed-precondition`.
Three valid ways to run untethered, simplest first:

| Mode | How | Attestation | Console step |
|------|-----|-------------|--------------|
| **A. Debug build, unplugged** | `flutter run`, then unplug the cable (you lose hot-reload, app keeps running) | Debug provider | Register the debug token the app prints on first launch |
| **B. Release + forced debug** | `flutter run --release --dart-define=FORCE_APPCHECK_DEBUG=true` | Debug provider | Register the debug token |
| **C. True release / Play** | `flutter build apk --release` or Internal Testing track | **Play Integrity** | Register Play Integrity + SHA-256 |

For a quick "works on my phone" test, **Mode A or B** is the path. Mode C is for
real distribution.

---

## 1. ⛔ BLOCKER — enable the App Check API + register the app

Per prior debugging, the **Firebase App Check API was disabled** in `shiru-bcdd2`.
While disabled, *nothing* in Storytime works regardless of build mode. Fix first.

1. Firebase Console → **App Check** (or enable `firebaseappcheck.googleapis.com`).
2. Register the **Android app** (`1:310525193859:android:c293b47e0c7331a26475b6`).
3. **For Mode A/B (debug token):**
   - Launch the app once; logcat prints a line like
     `Enter this debug secret into the allow list: XXXXXXXX-XXXX-...`.
   - App Check → your Android app → **Manage debug tokens** → add it.
   - `adb logcat | grep -i "debug secret"` to grab it.
4. **For Mode C (Play Integrity):**
   - Enable the **Play Integrity** provider on the Android app.
   - Add your **release signing SHA-256** (Project Settings → your Android app →
     Add fingerprint). Get it with:
     `keytool -list -v -keystore <release.keystore> -alias <alias>`.

Verify enabled (needs gcloud, optional):
`gcloud services list --enabled --project shiru-bcdd2 | grep appcheck`

---

## 2. ⛔ BLOCKER — Auth sign-in providers

The non-emulator path does **not** sign in anonymously. The user signs in with
**Email/Password, Google, or Apple** (`auth_repository.dart`), and every callable
needs `request.auth`. Enable in Console → **Authentication → Sign-in method**:

- **Email/Password** — always works, no extra device config. Easiest for a test.
- **Google** — also requires your build's **SHA-1** in the Firebase Android app
  (Google Sign-In on Android won't return an idToken otherwise). `google-services.json`
  currently has 2 oauth_client entries — confirm the SHA you're signing with is among them.
- **Apple** — iOS-only; ignore for Android.

> Make sure the app's sign-in screen is actually reached before any story is
> generated — an unauthenticated call returns `unauthenticated` immediately.

---

## 3. ⛔ BLOCKER — Signed-URL IAM for the "story ready" step

`processStoryJob` calls `file.getSignedUrl(...)`. In gen2 functions this signs via
IAM `signBlob`, which needs:

- API **`iamcredentials.googleapis.com`** enabled.
- The functions runtime service account
  (`shiru-bcdd2@appspot.gserviceaccount.com`, or the gen2 default compute SA)
  holding **`roles/iam.serviceAccountTokenCreator` on itself**.

Because App Check has blocked prod end-to-end so far, this path may never have
actually run in prod — so a story can reach `narrating` then fail at `ready` with a
`provider` error if this is missing. Grant:

```sh
gcloud projects add-iam-policy-binding shiru-bcdd2 \
  --member="serviceAccount:<runtime-sa>@..." \
  --role="roles/iam.serviceAccountTokenCreator"
```

---

## 4. Deploy rules (confirm they're live, not just in the repo)

The repo has `firestore.rules`, `storage.rules`, `firestore.indexes.json` (empty —
fine). Deploy to be sure the device hits the right rules:

```sh
firebase deploy --only firestore:rules,storage --project shiru-bcdd2
```

Rules are already correct: clients can only **read** their own `users/{uid}/...`
docs (all writes are server-side via functions), and may **write** voice samples to
`voice-samples/{uid}/{voiceId}/...`.

---

## 5. Functions — deploy the family-voice pipeline

Currently deployed (core story flow — complete):
`createStoryJob`, `processStoryJob`, `confirmStoryImported`, `joinFamilyVoiceWaitlist`,
`deleteAccountData`, `cleanupExpiredStoryAudio`.

**Not yet deployed** (the voice-clone functions — needed since Family Voice is in scope):
`createVoiceConsent`, `submitVoiceClone`, `processVoiceClone`, `deleteVoice`.

```sh
cd functions && npm run build
firebase deploy --only functions --project shiru-bcdd2   # deploys all 10
```

---

## 6. Function secrets (5 — required by processStoryJob / voice pipeline)

These must exist in Secret Manager or the functions fail at runtime:
`ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`,
`ELEVENLABS_VOICE_WALLY`, `ELEVENLABS_VOICE_FERN`, `ELEVENLABS_VOICE_RAY`.

The 6 deployed functions reference these, so deploy would have failed without them —
they almost certainly exist. To set/rotate one:
`firebase functions:secrets:set ELEVENLABS_API_KEY --project shiru-bcdd2`.
(The `ELEVENLABS_VOICE_*` secrets are the provider voice IDs for the 3 built-in narrators.)

---

## 7. Firestore config docs (control flags the functions read)

Create these docs (Console → Firestore) or story creation is blocked / mis-quota'd:

- **`storytimeConfig/generation`**
  - `enabled: true`  (if `false`, `createStoryJob` → `unavailable`)
  - `dailyQuota: 10`  (per-user/day cap; defaults to 10 if absent)
- **`storytimeConfig/familyVoice`**
  - `enabled: true`  ← **flip on** to allow voice cloning + family-narrator stories
    (defaults to enabled unless explicitly `false`; set it explicitly to be safe)

---

## 8. Install & verify on the phone

```sh
# Mode A — debug, then unplug:
flutter run                       # from app/, with phone connected; then unplug

# Mode B — release-signed but debug attestation:
flutter run --release --dart-define=FORCE_APPCHECK_DEBUG=true
```

Do NOT pass `--dart-define=USE_EMULATOR=true` — that points the app back at the Mac.

Smoke test on-device:
1. Enter parent area (PIN `1111`), sign in (email/password is simplest).
2. Generate a story → watch it go `queued → writing → checking → narrating → ready`,
   then play. (Confirms App Check + Auth + Anthropic + ElevenLabs + signed URL.)
3. Record a family voice → `consented → queued → cloning → ready` → use it in a story.
   (Confirms the newly deployed voice pipeline + Storage write rules.)

---

## Status — VERIFIED end-to-end 2026-07-04

Generated + played "Splash and the Singing Shells" on a real Android device, untethered.

| Item | State |
|------|-------|
| App Check API + Android debug token | ✅ |
| Auth (Email/Password) | ✅ |
| Signed-URL IAM (token-creator + iamcredentials) | ✅ (was the final blocker) |
| Firestore/Storage rules deployed | ✅ |
| All 10 functions deployed | ✅ |
| `processStoryJob`/`processVoiceClone` in europe-west1 (matches eur3 DB) | ✅ |
| Function secrets present | ✅ |
| `storytimeConfig` docs | ✅ |

## iOS (connected device) — also VERIFIED 2026-07-04

Backend is shared, so iOS only needed its own App Check registration. What differed:
- **Xcode signing first:** `flutter run` on a physical iPhone needs an Apple account in
  Xcode (Settings → Accounts) matching team `76VTN54W9Y`, else "No profiles for
  'com.shiru.app'". After first install, **trust** the cert on-device (Settings →
  General → VPN & Device Management → Trust) or the app won't launch (Dart VM never
  connects).
- **Debug token:** iOS prints `Firebase App Check Debug Token: <UUID>` to the **flutter
  run console** (not reliably via `idevicesyslog` on iOS 26). Register it under the iOS
  app → Manage debug tokens (provider: App Attest for prod).
- **No device UI automation** for a physical iPhone (no adb equivalent; the sim MCP is
  sim-only) — the user taps through; verify via server logs / on-screen result.

## Two gotchas hit during setup

- **DB region:** Firestore is `eur3`. gen2 **Firestore triggers** must be co-located,
  so `processStoryJob`/`processVoiceClone` live in **europe-west1**. A trigger left in
  us-central1 never fires (story hangs at `queued`). Region is immutable on update —
  `firebase functions:delete <fn> --region us-central1` then redeploy to auto-place it.
  **Callables stay us-central1** (Flutter SDK default) — don't move those.
- **Stale cached user:** a leftover emulator anonymous user on the device gives
  `INVALID_REFRESH_TOKEN` → Firestore reads `UNAUTHENTICATED` and `createStoryJob`
  throws client-side before hitting the server (shows "Story making is resting", no
  server log). Fix: Grown-up → Account → **Sign out**, then sign in fresh.
- Note: the app's "Story making is resting" copy is a **catch-all** for any callable
  error except `resource-exhausted` — not specifically the `generation.enabled` flag.
