#!/usr/bin/env bash
# Local CI for BT Audio Idle Disconnect: everything that must pass before a push or a release.
#
#   scripts/ci.sh [--help]
#
# Steps: shell syntax (+ shellcheck when installed) → plist/strings lint → swift build → swift test.
# There is no hosted CI workflow on purpose (macOS runner minutes are billed at 10x); this script is
# the CI. Enable the pre-push hook with:  git config core.hooksPath .githooks
set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    "") ;;
    *) die "unknown argument: $1 (see --help)" ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v swift >/dev/null || die "swift not found (install Xcode or a Swift toolchain)"

log "Shell scripts: bash -n"
shell_files=(scripts/*.sh .githooks/*)
for f in "${shell_files[@]}"; do
    [ -f "$f" ] || continue
    bash -n "$f" || die "syntax error in $f"
done
if command -v shellcheck >/dev/null; then
    log "Shell scripts: shellcheck"
    shellcheck -S warning "${shell_files[@]}"
else
    log "shellcheck not installed — skipping (brew install shellcheck)"
fi

log "Property lists and .strings: plutil -lint"
while IFS= read -r -d '' f; do
    plutil -lint -s "$f" || die "invalid file: $f"
done < <(find Resources -type f \( -name '*.plist' -o -name '*.strings' \) -print0)

log "swift build"
swift build

log "swift test"
swift test

log "CI passed"
