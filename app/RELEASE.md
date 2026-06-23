# Shiru Release Notes

## Draft Store Notes

### Version 1.0.0

Release date: 2026-04-11

First public release. These notes cover the full shipped v1 feature set.

#### Short Store Copy

First public release of Shiru, a calm local-first audio and video player for kids.

#### Full Release Notes

- First public release of Shiru.
- Record stories or videos and import audio or video into a kid-friendly local library.
- Organize cards with categories and artwork, including mixed bulk import and media export.
- Protect parent settings with a PIN and age gate, with local-first privacy and safety hardening.
- Includes responsive layouts for phones and tablets, plus a first-run welcome note and About screen.

## Release Build Checklist

## Android

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Put your signing keystore under `android/keystore/`.
3. Update the values in `android/key.properties` to match your keystore.
4. Run:

```sh
./build_release.sh
```

Artifacts:
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

## iOS

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Confirm bundle ID `com.shiru.app`.
3. Select the correct Apple signing team/profile.
4. Archive the app from Xcode and validate the archive before upload.

## Preflight

- Run `flutter test`
- Run `flutter analyze`
- Run `flutter build apk --debug` and complete signed release builds for both platforms
- Verify parent auth resets when leaving the parent area

## Media and permission checks

- Audio import: MP3, M4A, WAV, and AAC; reject empty files and files over 200 MB.
- Video import/recording: MP4, MOV, and M4V; reject empty files, videos over
  15 minutes, files over 1 GB, and codecs the native player cannot initialize.
- iOS: verify the camera, photo-library, and microphone usage descriptions before
  archiving. Denial and permanent denial must leave the parent flow recoverable.
- Android: do not add camera or storage permissions. Gallery/camera selection uses
  system intents; audio recording alone requests microphone permission.

## Physical-device verification matrix

Complete every cell on at least one currently supported phone or tablet before
publishing. Simulators are useful for layout checks but do not replace camera,
microphone, codec, storage, and lifecycle testing.

| Scenario | Android | iOS |
| --- | --- | --- |
| Import and play MP4, MOV, and M4V samples with sound | [ ] | [ ] |
| Record a video with sound, save it, and replay it | [ ] | [ ] |
| Cancel and deny gallery/camera/microphone access without losing parent auth | [ ] | [ ] |
| Pause video by backgrounding; return and replay/seek/close | [ ] | [ ] |
| Reject a video over 15 minutes and a file over 1 GB | [ ] | [ ] |
| Report an unsupported/corrupt codec without crashing | [ ] | [ ] |
| Mixed audio/video bulk import keeps valid drafts when one file fails | [ ] | [ ] |
| Edit/replace, export, and delete media; confirm unreferenced files are cleaned | [ ] | [ ] |
| Verify landscape phone and tablet layouts, including video badges and controls | [ ] | [ ] |
| Simulate low storage and confirm a recoverable import error | [ ] | [ ] |
