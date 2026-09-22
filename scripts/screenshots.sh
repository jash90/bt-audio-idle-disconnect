#!/bin/bash
# Regenerates the GitHub Pages screenshots in site/assets/screenshots/.
#
# Compiles the app's real sources together with scripts/screenshots/*.swift — which
# replace main.swift, BluetoothManager.swift and AppRunningMonitor.swift with fictional
# devices and apps — into a throwaway .app, then renders the real windows in light and
# dark mode. The shipped app and your real settings/logs are never touched: the harness
# runs with CFFIXED_USER_HOME pointing at a non-existent home, so nothing is written.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="Sources/BTAudioIdleDisconnect"
HARNESS_DIR="scripts/screenshots"
WORK="build/screenshots"
APP="$WORK/BTAudioIdleScreenshots.app"
RAW="$WORK/raw"
OUT="site/assets/screenshots"
FAKE_HOME="/Users/demo"   # does not exist → settings.json / log writes fail silently

echo "→ Compiling screenshot harness"
rm -rf "$WORK"
mkdir -p "$APP/Contents/MacOS" "$RAW" "$OUT"

APP_SOURCES=()
for f in "$SRC"/*.swift; do
    case "$(basename "$f")" in
        main.swift|BluetoothManager.swift|AppRunningMonitor.swift) ;;
        *) APP_SOURCES+=("$f") ;;
    esac
done

swiftc -O -target arm64-apple-macosx13.0 \
    -o "$APP/Contents/MacOS/BTAudioIdleScreenshots" \
    "${APP_SOURCES[@]}" "$HARNESS_DIR"/*.swift \
    -framework AppKit -framework SwiftUI -framework CoreAudio \
    -framework UserNotifications -framework ServiceManagement 2>&1 | grep -v "^$" || true
test -x "$APP/Contents/MacOS/BTAudioIdleScreenshots"

sed -e 's/<string>BTAudioIdleDisconnect<\/string>/<string>BTAudioIdleScreenshots<\/string>/' \
    -e 's/com\.bartlomiejzimny\.btaudioidle/com.example.btaudioidle.screenshots/' \
    Resources/Info.plist > "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1

for mode in light dark; do
    echo "→ Rendering ($mode)"
    # `open` goes through LaunchServices so the harness is activated and its windows
    # render in their active (key) state.
    open -W -n --env CFFIXED_USER_HOME="$FAKE_HOME" "$APP" --args "$ROOT/$RAW" "$mode"
done

echo "→ Converting to WebP"
for png in "$RAW"/*.png; do
    name="$(basename "$png" .png)"
    cwebp -quiet -q 88 -m 6 "$png" -o "$OUT/$name.webp"
done

ls -la "$OUT"
echo "✓ Screenshots in $OUT"
