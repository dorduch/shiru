# Storytime Firebase setup

The app retains Firebase project `shiru-bcdd2` and bundle IDs. Complete these
console-owned steps before testing production authentication or generation:

1. Enable Email/Password and Google providers in Firebase Auth. Apple login is
   deferred for now; leave the Apple provider disabled.
2. Add Android SHA-1 and SHA-256 fingerprints, then replace
   `app/android/app/google-services.json` with the regenerated file.
3. Configure the iOS Google OAuth client and replace
   `app/ios/Runner/GoogleService-Info.plist`; it must contain `CLIENT_ID` and
   `REVERSED_CLIENT_ID`. Add the reversed client ID as a URL scheme in Xcode.
4. Create Firestore and the default Storage bucket, then deploy rules,
   indexes, and Functions with `firebase deploy`.
5. Register App Check debug tokens during development. Enable Play Integrity
   for Android and App Attest for iOS before enforcing App Check.
6. Set Functions secrets:

   ```sh
   firebase functions:secrets:set ANTHROPIC_API_KEY
   firebase functions:secrets:set ELEVENLABS_API_KEY
   firebase functions:secrets:set ELEVENLABS_VOICE_WALLY
   firebase functions:secrets:set ELEVENLABS_VOICE_FERN
   firebase functions:secrets:set ELEVENLABS_VOICE_RAY
   ```

7. Create `storytimeConfig/generation` with `enabled: true` and
   `dailyLimit: 3`. Set provider budget alerts and rotate any keys that were
   previously bundled in `assets/.env`.

The WAV files under `app/assets/storytime` are local draft narrations. Replace
them with editorially reviewed, licensed production audio and previews before
release without changing the manifest paths.
