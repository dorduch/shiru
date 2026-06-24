# Storytime

Storytime is a Flutter app for children ages 3–10. A parent creates an account
and one local child profile; the child chooses a character, scene, theme, plot,
and narrator to make a safe audio story. Stories are downloaded into an
encrypted on-device library for independent listening and resume.

The Flutter app lives in `app/`. Firebase Auth handles parent accounts, while
the TypeScript project in `functions/` performs generation, safety review,
narration, quota enforcement, and temporary audio cleanup. Anthropic and
ElevenLabs credentials exist only in Firebase Secret Manager.

## Development

```sh
cd app
flutter pub get
flutter run
flutter analyze
flutter test

cd ../functions
npm install
npm run build
npm test
```

See `docs/STORYTIME_FIREBASE_SETUP.md` before testing authentication or cloud
generation. The Firebase providers, App Check registrations, Functions
secrets, and production narrator voice IDs are console-owned prerequisites.
