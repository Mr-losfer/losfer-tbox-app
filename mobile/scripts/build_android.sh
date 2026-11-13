#!/usr/bin/env bash
# Noqi — Android 打包（Flutter 3.35+ / JDK 17+ / Android SDK 35+）
# 产物：dist/android/Noqi-<版本>-arm64-v8a.apk（真机首选，体积最小）
#       dist/android/Noqi-<版本>-universal.apk（全架构兜底）
#       dist/android/Noqi-<版本>.aab（Google Play 上架）
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep '^version:' pubspec.yaml | sed 's/version: *//;s/+.*//')"
OUT="dist/android"
mkdir -p "$OUT"

flutter pub get
flutter test
flutter analyze --no-fatal-infos

echo "▶ arm64（体积最小，真机首选）"
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/Noqi-$VERSION-arm64-v8a.apk"

echo "▶ universal（arm64 + armv7 + x86_64）"
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/Noqi-$VERSION-universal.apk"

echo "▶ appbundle（应用商店）"
flutter build appbundle --release
cp build/app/outputs/bundle/release/app-release.aab "$OUT/Noqi-$VERSION.aab"

ls -lh "$OUT"
