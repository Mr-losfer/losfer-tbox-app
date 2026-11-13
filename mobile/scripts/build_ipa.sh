#!/usr/bin/env bash
# Noqi — iOS 打包（必须 macOS + Xcode 15+）
#   bash scripts/build_ipa.sh              # 签名导出（需已配置 Team 证书）
#   bash scripts/build_ipa.sh --unsigned   # 不签名，产出可重签的 IPA
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
(cd ios && pod install)

if [[ "${1:-}" == "--unsigned" ]]; then
  echo "▶ 无签名构建（用于企业重签 / AltStore 侧载）"
  flutter build ios --release --no-codesign
  rm -rf build/ipa_payload && mkdir -p build/ipa_payload/Payload
  cp -R build/ios/iphoneos/Runner.app build/ipa_payload/Payload/
  (cd build/ipa_payload && zip -qry ../Noqi-unsigned.ipa Payload)
  echo "✓ build/Noqi-unsigned.ipa"
else
  : "${TEAM_ID:?请先设置 TEAM_ID 环境变量（Apple Developer Team ID）}"
  echo "▶ 签名构建 (Team: $TEAM_ID)"
  flutter build ipa --release \
    --export-method development \
    --build-number "${BUILD_NUMBER:-1}"
  echo "✓ build/ios/ipa/Noqi.ipa"
fi
