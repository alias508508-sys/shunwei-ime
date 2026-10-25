#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="macos/build/Shunwrite.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
npx esbuild web/src/core/native.ts --bundle --format=iife --global-name=SmartEngine --outfile=macos/build/engine.js
npx tsx tests/native-fixtures.ts
cp macos/build/fixtures.json "$app/Contents/Resources/fixtures.json"
cp -R macos/Resources/. "$app/Contents/Resources/"
cp macos/Info.plist "$app/Contents/Info.plist"
cp macos/build/engine.js "$app/Contents/Resources/engine.js"
xcrun swiftc -O -module-name Shunwrite -target arm64-apple-macos14.0 -framework AppKit -framework InputMethodKit -framework JavaScriptCore macos/Sources/*.swift -o "$app/Contents/MacOS/Shunwrite"
mkdir -p "$app/Contents/Resources/ThirdParty"
cp docs/THIRD_PARTY_NOTICES.md docs/sources.json data/upstream/jieba-LICENSE data/upstream/cmudict-LICENSE "$app/Contents/Resources/ThirdParty/"
codesign --force --sign - "$app"
"$app/Contents/MacOS/Shunwrite" --smoke-test

"$app/Contents/MacOS/Shunwrite" --controller-test

"$app/Contents/MacOS/Shunwrite" --startup-check
