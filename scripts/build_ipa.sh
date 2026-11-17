#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

python3 scripts/generate_app_icon.py
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
xcodegen generate

xcodebuild clean build \
  -project Null.xcodeproj \
  -target Null \
  -configuration Release \
  -sdk iphoneos \
  SYMROOT="$PWD/build" \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES

rm -rf build/ipa build/ipa-noext
mkdir -p build/ipa/Payload build/ipa-noext/Payload

cp -R build/Release-iphoneos/Null.app build/ipa/Payload/
for appex in build/ipa/Payload/Null.app/PlugIns/*.appex; do
  [ -d "$appex" ] && codesign --force --deep --sign - "$appex"
done
codesign --force --deep --sign - build/ipa/Payload/Null.app
(cd build/ipa && zip -r ../../Null.ipa Payload)

cp -R build/Release-iphoneos/Null.app build/ipa-noext/Payload/
rm -rf build/ipa-noext/Payload/Null.app/PlugIns
codesign --force --deep --sign - build/ipa-noext/Payload/Null.app
(cd build/ipa-noext && zip -r ../../Null-NoExtension.ipa Payload)

ls -lh Null.ipa Null-NoExtension.ipa
