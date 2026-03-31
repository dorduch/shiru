#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f android/key.properties ]; then
  echo "Error: android/key.properties not found."
  echo "Copy android/key.properties.example to android/key.properties and add your release signing values."
  exit 1
fi

echo "==> Cleaning..."
flutter clean
flutter pub get

echo "==> Running tests..."
flutter test

echo "==> Building release app bundle..."
flutter build appbundle

echo "==> Building release APK..."
flutter build apk --release

APP_BUNDLE="build/app/outputs/bundle/release/app-release.aab"
APK="build/app/outputs/flutter-apk/app-release.apk"

echo "==> Built AAB: $APP_BUNDLE"
echo "==> Built APK: $APK"
