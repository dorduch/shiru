# Shiru Release Notes

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
