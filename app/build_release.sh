#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f env.json ]; then
  echo "Error: env.json not found. Create it with OPENAI_API_KEY, CARTESIA_API_KEY, GIPHY_API_KEY."
  exit 1
fi

echo "==> Cleaning..."
flutter clean
flutter pub get

echo "==> Building release APK..."
flutter build apk --dart-define-from-file=env.json

APK="build/app/outputs/flutter-apk/app-release.apk"
echo "==> Built: $APK"

if [ "${1:-}" = "--install" ]; then
  DEVICE="${2:-}"
  if [ -n "$DEVICE" ]; then
    echo "==> Installing on $DEVICE..."
    flutter install --device-id "$DEVICE"
  else
    echo "==> Installing on default device..."
    flutter install
  fi
fi
