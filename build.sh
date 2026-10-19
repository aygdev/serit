#!/bin/bash
# Derler ve ~/Applications/Şerit.app olarak kurar.
set -euo pipefail
cd "$(dirname "$0")"
if [ -d /Applications/Xcode.app ]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi
OUT="${TMPDIR:-/tmp}/serit-build/Şerit.app"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"
xcrun -sdk macosx swiftc -O -swift-version 5 -target arm64-apple-macos26.0 -parse-as-library \
  Sources/*.swift -o "$OUT/Contents/MacOS/Serit"
cp Info.plist "$OUT/Contents/Info.plist"
codesign --force --sign - "$OUT"
mkdir -p "$HOME/Applications"
pkill -x Serit 2>/dev/null || true
rm -rf "$HOME/Applications/Şerit.app"
cp -R "$OUT" "$HOME/Applications/Şerit.app"
echo "Kuruldu: $HOME/Applications/Şerit.app"
