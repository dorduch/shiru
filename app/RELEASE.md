# Shiru Release Notes

## Draft Store Notes

### Version 1.0.0

Release date: 2026-04-11

First public release. These notes cover the full shipped v1 feature set.

#### Short Store Copy

First public release of Shiru, a calm local-first audio player for kids.

#### Full Release Notes

- First public release of Shiru.
- Record stories and import songs or audiobooks into a kid-friendly audio library.
- Organize cards with categories and artwork, including bulk import and export.
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
- Verify record/import/playback flows on a real device
- Verify parent auth resets when leaving the parent area
