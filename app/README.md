# Shiru Flutter app

Run commands from this directory:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

Supported video imports are MP4, MOV, and M4V, limited to 15 minutes and 1 GB.
Native codec support varies by device, so release verification must include the
physical-device matrix in `RELEASE.md`.

## Known issue: iOS 26 simulator crash on a fresh checkout

A fresh checkout (or any run after an Xcode/runtime update) can crash at launch
on the iOS **26.0** simulator before any Flutter UI paints, with:

```
Unhandled Exception: Couldn't resolve native function 'DOBJC_initializeApi' ...
Failed to load dynamic library 'objective_c.framework/objective_c'
```

The screen stays on the native launch screen and the accessibility tree stays
empty. This is a stale native-assets/Pods build cache (the `objective_c`
framework, pulled in transitively via FFI, gets built/linked against a
now-invalid SDK path) — not a code regression.

**Fix:** from `app/`, do a full clean rebuild before assuming the simulator is
unusable:

```sh
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks build .dart_tool
flutter pub get
flutter run -d <ios-26-sim-udid>   # pod install runs automatically; build ~5 min
```

Note: a `Target native_assets required define SdkRoot but it was not provided`
warning can still print after the fix — that's benign on its own. The
dylib-load `Unhandled Exception` is the real failure, and it goes away once the
clean rebuild above completes.
