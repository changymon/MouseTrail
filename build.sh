#!/bin/zsh
# Builds MouseTrail.app next to this script (local development build).
# Sandboxed + ad-hoc signed, matching App Store runtime behavior.
set -e
cd "$(dirname "$0")"

APP="MouseTrail.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary: Apple Silicon + Intel.
swiftc -O -target arm64-apple-macos13.0  -o /tmp/mousetrail-arm64  main.swift -framework Cocoa
swiftc -O -target x86_64-apple-macos13.0 -o /tmp/mousetrail-x86_64 main.swift -framework Cocoa
lipo -create /tmp/mousetrail-arm64 /tmp/mousetrail-x86_64 -output "$APP/Contents/MacOS/MouseTrail"
rm /tmp/mousetrail-arm64 /tmp/mousetrail-x86_64
cp Info.plist "$APP/Contents/Info.plist"
cp icon/MouseTrail.icns "$APP/Contents/Resources/MouseTrail.icns"
codesign --force --sign - --entitlements MouseTrail.entitlements "$APP"

echo "Built $PWD/$APP"
