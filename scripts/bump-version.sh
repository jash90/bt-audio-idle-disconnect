#!/usr/bin/env bash
# Bump the app version and commit it.
#
#   scripts/bump-version.sh X.Y.Z [--build N] [--no-commit]
#
# Writes CFBundleShortVersionString = X.Y.Z and CFBundleVersion = N (default: current + 1) into
# Resources/Info.plist — the only version file — verifies the values, and commits
# "chore: release X.Y.Z". It does not tag or push; scripts/release.sh does that.
set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PLIST="Resources/Info.plist"
PB=/usr/libexec/PlistBuddy

VERSION=""
BUILD=""
COMMIT=1
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --build) BUILD="${2:-}"; shift 2 ;;
        --no-commit) COMMIT=0; shift ;;
        -*) die "unknown option: $1 (see --help)" ;;
        *) [ -z "$VERSION" ] || die "unexpected argument: $1"; VERSION="$1"; shift ;;
    esac
done

[ -n "$VERSION" ] || { usage; exit 1; }
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be X.Y.Z (got '$VERSION')"

OLD_VERSION="$($PB -c 'Print :CFBundleShortVersionString' "$PLIST")"
OLD_BUILD="$($PB -c 'Print :CFBundleVersion' "$PLIST")"
[[ "$OLD_BUILD" =~ ^[0-9]+$ ]] || die "CFBundleVersion in $PLIST is not an integer: $OLD_BUILD"

if [ -z "$BUILD" ]; then BUILD=$((OLD_BUILD + 1)); fi
[[ "$BUILD" =~ ^[0-9]+$ ]] || die "--build must be an integer"
[ "$BUILD" -gt "$OLD_BUILD" ] || die "CFBundleVersion must increase ($OLD_BUILD → $BUILD)"

# Refuse to go backwards: sort -V puts the larger version last.
if [ "$VERSION" != "$OLD_VERSION" ] && \
   [ "$(printf '%s\n%s\n' "$OLD_VERSION" "$VERSION" | sort -V | tail -1)" != "$VERSION" ]; then
    die "new version $VERSION is lower than current $OLD_VERSION"
fi

if [ "$COMMIT" = 1 ] && ! git diff --quiet -- "$PLIST"; then
    die "$PLIST has uncommitted changes; commit or stash them first"
fi

log "$OLD_VERSION ($OLD_BUILD) → $VERSION ($BUILD)"
$PB -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
$PB -c "Set :CFBundleVersion $BUILD" "$PLIST"
plutil -lint -s "$PLIST"

[ "$($PB -c 'Print :CFBundleShortVersionString' "$PLIST")" = "$VERSION" ] || die "version write failed"
[ "$($PB -c 'Print :CFBundleVersion' "$PLIST")" = "$BUILD" ] || die "build write failed"

if [ "$COMMIT" = 1 ]; then
    git add "$PLIST"
    git commit -q -m "chore: release $VERSION"
    log "Committed 'chore: release $VERSION'. Next: scripts/release.sh"
else
    log "Updated $PLIST (not committed)"
fi
