#!/bin/zsh
# Builds MouseTrail.app next to this script (local development build).
# Sandboxed + ad-hoc signed, matching App Store runtime behavior.
set -e
cd "$(dirname "$0")"

APP="MouseTrail.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -o "$APP/Contents/MacOS/MouseTrail" main.swift -framework Cocoa
cp Info.plist "$APP/Contents/Info.plist"
cp icon/MouseTrail.icns "$APP/Contents/Resources/MouseTrail.icns"
codesign --force --sign - --entitlements MouseTrail.entitlements "$APP"

echo "Built $PWD/$APP"
