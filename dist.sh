#!/bin/zsh
# Builds a Mac App Store submission package: MouseTrail.pkg
#
# Prerequisites (see SUBMISSION.md):
#   1. Apple Developer Program membership.
#   2. Certificates in your keychain:
#        "Apple Distribution: <Your Name> (TEAMID)"
#        "3rd Party Mac Developer Installer: <Your Name> (TEAMID)"
#      (Xcode > Settings > Accounts > Manage Certificates creates these.)
#   3. A Mac App Store provisioning profile for au.changy.mousetrail,
#      downloaded from developer.apple.com and saved next to this script
#      as MouseTrail.provisionprofile
#
# Then run:  ./dist.sh
set -e
cd "$(dirname "$0")"

APP_SIGN_ID=$(security find-identity -v -p codesigning | grep "Apple Distribution" | head -1 | sed 's/.*"\(.*\)"/\1/')
PKG_SIGN_ID=$(security find-identity -v | grep "3rd Party Mac Developer Installer" | head -1 | sed 's/.*"\(.*\)"/\1/')

if [[ -z "$APP_SIGN_ID" ]]; then
  echo "error: no 'Apple Distribution' certificate found in your keychain." >&2
  echo "Create one in Xcode > Settings > Accounts > Manage Certificates." >&2
  exit 1
fi
if [[ -z "$PKG_SIGN_ID" ]]; then
  echo "error: no '3rd Party Mac Developer Installer' certificate found in your keychain." >&2
  echo "Create one in Xcode > Settings > Accounts > Manage Certificates ('Mac Installer Distribution')." >&2
  exit 1
fi
if [[ ! -f MouseTrail.provisionprofile ]]; then
  echo "error: MouseTrail.provisionprofile not found next to this script." >&2
  echo "Create a 'Mac App Store Connect' provisioning profile for au.changy.mousetrail" >&2
  echo "at developer.apple.com > Certificates, Identifiers & Profiles > Profiles." >&2
  exit 1
fi

echo "App signing identity: $APP_SIGN_ID"
echo "Pkg signing identity: $PKG_SIGN_ID"

APP="dist/MouseTrail.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -o "$APP/Contents/MacOS/MouseTrail" main.swift -framework Cocoa
cp Info.plist "$APP/Contents/Info.plist"
cp icon/MouseTrail.icns "$APP/Contents/Resources/MouseTrail.icns"
cp MouseTrail.provisionprofile "$APP/Contents/embedded.provisionprofile"

codesign --force --timestamp \
  --sign "$APP_SIGN_ID" \
  --entitlements MouseTrail.entitlements \
  "$APP"

codesign --verify --deep --strict "$APP"

productbuild \
  --component "$APP" /Applications \
  --sign "$PKG_SIGN_ID" \
  dist/MouseTrail.pkg

echo ""
echo "Built dist/MouseTrail.pkg"
echo "Upload it with the Transporter app (free on the Mac App Store),"
echo "or via Xcode. See SUBMISSION.md for the full checklist."
