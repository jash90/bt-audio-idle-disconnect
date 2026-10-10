#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="BTAudioIdleDisconnect"
DISPLAY_NAME="BT Audio Idle"
APP_BUNDLE="build/${DISPLAY_NAME}.app"

echo "→ Building release executable…"
swift build -c release

echo "→ Creating ${APP_BUNDLE}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Localizations (en = development region, pl): Localizable.strings + InfoPlist.strings.
for lproj in Resources/*.lproj; do
    if [ -d "$lproj" ]; then cp -R "$lproj" "$APP_BUNDLE/Contents/Resources/"; fi
done

# Ad-hoc by default (ADR-001). scripts/release.sh --developer-id sets CODESIGN_IDENTITY to a
# Developer ID certificate (SHA-1); a real identity also gets a secure timestamp for notarization.
IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
    echo "→ Ad-hoc signing (required for notifications, SMAppService)"
    codesign --force --deep --options runtime --sign - "$APP_BUNDLE"
else
    echo "→ Signing with identity $IDENTITY (hardened runtime + timestamp)"
    codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP_BUNDLE"
fi

echo
echo "✓ Built $APP_BUNDLE"
echo
echo "Next steps:"
echo "  1. Move into /Applications:"
echo "       mv \"$APP_BUNDLE\" /Applications/"
echo "  2. First launch: open \"/Applications/${DISPLAY_NAME}.app\""
echo "     (Right-click → Open if Gatekeeper complains.)"
echo "  3. Grant Notification permission when prompted."
echo "  4. (Optional) Enable 'Launch at login' in Preferences."
