#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DISPLAY_NAME="BT Audio Idle"
APP_BUNDLE="build/${DISPLAY_NAME}.app"
VOL_NAME="$DISPLAY_NAME"
DMG_PATH="build/${DISPLAY_NAME}.dmg"

# Build the app first if it is missing.
if [ ! -d "$APP_BUNDLE" ]; then
    echo "→ App bundle missing, running build-app.sh first…"
    "$ROOT/scripts/build-app.sh"
fi

# Pull the version from the bundle so the DMG name carries it.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || echo "")"
if [ -n "$VERSION" ]; then
    DMG_PATH="build/${DISPLAY_NAME} ${VERSION}.dmg"
fi
# scripts/release.sh passes an explicit output path.
DMG_PATH="${DMG_OUT:-$DMG_PATH}"

echo "→ Staging contents"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "→ Creating ${DMG_PATH}"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

echo
echo "✓ Built $DMG_PATH"
echo
echo "Distribute: send the .dmg. Recipient opens it and drags"
echo "\"${DISPLAY_NAME}.app\" onto the Applications shortcut."
echo "(Ad-hoc signed → first launch needs right-click → Open.)"
