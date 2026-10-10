#!/usr/bin/env bash
# Build, verify and publish a release of BT Audio Idle from this Mac.
#
#   scripts/release.sh [--dry-run] [--draft] [--skip-ci] [--developer-id] [--notes FILE]
#
#   --dry-run       preflight + CI + build + verify into dist/release/vX.Y.Z/, then stop
#                   (no tag, no push, no GitHub release; git-state checks only warn)
#   --draft         create the GitHub release as a draft (the in-app updater ignores drafts)
#   --skip-ci       do not run scripts/ci.sh first
#   --developer-id  sign with $APPLE_SIGNING_IDENTITY (Developer ID, hardened runtime), notarize
#                   and staple via the notarytool profile $NOTARY_PROFILE. Default is ad-hoc
#                   signing (docs/second-brain/7-decisions/adr-001-ad-hoc-signing.md).
#   --notes FILE    release notes (Markdown); default: commit subjects since the previous tag
#
# The version comes from Resources/Info.plist (bump it first with scripts/bump-version.sh).
# Every published release satisfies the in-app updater contract: tag vX.Y.Z == CFBundleShortVersionString,
# exactly one .dmg asset with a GitHub sha256 digest, same bundle id, codesign --verify --deep --strict
# passes, and the release is neither a draft nor a prerelease. See RELEASING.md.
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

DRY_RUN=0 DRAFT=0 SKIP_CI=0 DEVELOPER_ID=0 NOTES_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --draft) DRAFT=1; shift ;;
        --skip-ci) SKIP_CI=1; shift ;;
        --developer-id) DEVELOPER_ID=1; shift ;;
        --notes) NOTES_FILE="${2:-}"; [ -f "$NOTES_FILE" ] || die "--notes: file not found: $NOTES_FILE"; shift 2 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO="jash90/bt-audio-idle-disconnect"
BUNDLE_ID="com.bartlomiejzimny.btaudioidle"
DISPLAY_NAME="BT Audio Idle"
APP_BUNDLE="build/${DISPLAY_NAME}.app"
PLIST="Resources/Info.plist"
PB=/usr/libexec/PlistBuddy
MIN_FREE_GB=3

# In dry-run, problems with git state are reported but do not stop the run.
check() { if [ "$DRY_RUN" = 1 ]; then warn "$* (ignored in --dry-run)"; else die "$*"; fi; }

# ---------------------------------------------------------------------------------------------
log "Preflight"

for tool in swift codesign hdiutil git shasum plutil ditto; do
    command -v "$tool" >/dev/null || die "required tool missing: $tool"
done
if [ "$DRY_RUN" = 0 ]; then
    command -v gh >/dev/null || die "gh (GitHub CLI) is required to publish"
    gh auth status >/dev/null 2>&1 || die "gh is not logged in (gh auth login)"
fi

if [ "$DEVELOPER_ID" = 1 ]; then
    ENV_FILE="$HOME/.config/local-release/apple.env"
    # shellcheck source=/dev/null
    [ -f "$ENV_FILE" ] && source "$ENV_FILE"
    : "${APPLE_SIGNING_IDENTITY:?--developer-id needs APPLE_SIGNING_IDENTITY (SHA-1 of the Developer ID cert)}"
    : "${APPLE_TEAM_ID:?--developer-id needs APPLE_TEAM_ID}"
    : "${NOTARY_PROFILE:?--developer-id needs NOTARY_PROFILE (xcrun notarytool store-credentials)}"
    security find-identity -v -p codesigning | grep -q "$APPLE_SIGNING_IDENTITY" \
        || die "signing identity $APPLE_SIGNING_IDENTITY not found in the keychain"
    xcrun --find notarytool >/dev/null && xcrun --find stapler >/dev/null || die "Xcode notarytool/stapler missing"
fi

VERSION="$($PB -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$($PB -c 'Print :CFBundleVersion' "$PLIST")"
PLIST_BUNDLE_ID="$($PB -c 'Print :CFBundleIdentifier' "$PLIST")"
TAG="v$VERSION"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "CFBundleShortVersionString must be X.Y.Z (got $VERSION)"
[[ "$BUILD" =~ ^[0-9]+$ ]] || die "CFBundleVersion must be an integer (got $BUILD)"
[ "$PLIST_BUNDLE_ID" = "$BUNDLE_ID" ] || die "bundle id changed to $PLIST_BUNDLE_ID — the updater would reject it"
log "Version $VERSION (build $BUILD), tag $TAG, signing: $([ "$DEVELOPER_ID" = 1 ] && echo "Developer ID" || echo ad-hoc)"

[ -z "$(git status --porcelain)" ] || check "working tree is not clean"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = main ] || check "not on main (on $BRANCH)"
git fetch -q origin main --tags || check "git fetch origin failed"
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || check "HEAD is not equal to origin/main"

# A tag that already exists is only OK when it points at HEAD and its release is still a draft
# (re-running after a failed upload). Anything else means the version was not bumped.
RESUME_DRAFT=0
EXISTING_RELEASE_DRAFT=""
if [ "$DRY_RUN" = 0 ]; then
    EXISTING_RELEASE_DRAFT="$(gh release view "$TAG" -R "$REPO" --json isDraft --jq .isDraft 2>/dev/null || true)"
fi
TAG_EXISTS=0
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && TAG_EXISTS=1
git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 && TAG_EXISTS=1
if [ "$EXISTING_RELEASE_DRAFT" = "true" ]; then
    RESUME_DRAFT=1
    log "Draft release $TAG exists — resuming it"
    if [ "$TAG_EXISTS" = 1 ]; then
        [ "$(git rev-parse "$TAG^{commit}" 2>/dev/null)" = "$(git rev-parse HEAD)" ] \
            || die "tag $TAG exists but does not point at HEAD"
    fi
elif [ "$EXISTING_RELEASE_DRAFT" = "false" ]; then
    die "release $TAG is already published — bump the version (scripts/bump-version.sh)"
elif [ "$TAG_EXISTS" = 1 ]; then
    check "tag $TAG already exists — bump the version (scripts/bump-version.sh)"
fi

# CFBundleVersion must grow relative to the previous release tag.
PREV_TAG="$(git tag --list 'v*' --sort=-v:refname | grep -vx "$TAG" | head -1 || true)"
if [ -n "$PREV_TAG" ]; then
    PREV_BUILD="$(git show "$PREV_TAG:$PLIST" 2>/dev/null | plutil -extract CFBundleVersion raw -o - - 2>/dev/null || echo 0)"
    if [[ "$PREV_BUILD" =~ ^[0-9]+$ ]] && [ "$BUILD" -le "$PREV_BUILD" ] && [ "$TAG" != "$PREV_TAG" ]; then
        die "CFBundleVersion $BUILD is not greater than $PREV_TAG's $PREV_BUILD"
    fi
fi

FREE_GB="$(df -g "$ROOT" | awk 'NR==2 {print $4}')"
[ "${FREE_GB:-0}" -ge "$MIN_FREE_GB" ] || die "only ${FREE_GB} GB free, need ${MIN_FREE_GB} GB"

# ---------------------------------------------------------------------------------------------
if [ "$SKIP_CI" = 0 ]; then
    log "CI (scripts/ci.sh)"
    scripts/ci.sh
else
    warn "--skip-ci: not running scripts/ci.sh"
fi

# ---------------------------------------------------------------------------------------------
OUT="dist/release/$TAG"
DMG_NAME="BT.Audio.Idle.$VERSION.dmg"   # GitHub would turn spaces into dots anyway
DMG="$OUT/$DMG_NAME"
rm -rf "$OUT"
mkdir -p "$OUT"

if [ "$DEVELOPER_ID" = 1 ]; then export CODESIGN_IDENTITY="$APPLE_SIGNING_IDENTITY"; else export CODESIGN_IDENTITY="-"; fi

log "Build app"
scripts/build-app.sh

verify_app() {   # verify_app <path-to-.app> <label>
    local app="$1" label="$2" info="$1/Contents/Info.plist"
    [ "$($PB -c 'Print :CFBundleIdentifier' "$info")" = "$BUNDLE_ID" ] || die "$label: wrong bundle id"
    [ "$($PB -c 'Print :CFBundleShortVersionString' "$info")" = "$VERSION" ] || die "$label: version != $VERSION"
    [ "$($PB -c 'Print :CFBundleVersion' "$info")" = "$BUILD" ] || die "$label: build != $BUILD"
    codesign --verify --deep --strict --verbose=2 "$app" || die "$label: codesign --verify --deep --strict failed"
    local details
    details="$(codesign -dvv "$app" 2>&1)"
    grep -q 'flags=.*runtime' <<<"$details" || die "$label: hardened runtime flag missing"
    if [ "$DEVELOPER_ID" = 1 ]; then
        grep -q "^TeamIdentifier=$APPLE_TEAM_ID\$" <<<"$details" || die "$label: TeamIdentifier is not $APPLE_TEAM_ID"
        grep -q '^Authority=Developer ID Application' <<<"$details" || die "$label: not signed with Developer ID"
    else
        grep -q '^Signature=adhoc' <<<"$details" || die "$label: expected an ad-hoc signature"
    fi
}

log "Verify app bundle"
verify_app "$APP_BUNDLE" "app"

if [ "$DEVELOPER_ID" = 1 ]; then
    log "Notarize app"
    ZIP="$OUT/app-notarize.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$ZIP"
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"
    spctl -a -vv -t execute "$APP_BUNDLE"
fi

log "Build DMG"
DMG_OUT="$DMG" scripts/build-dmg.sh

if [ "$DEVELOPER_ID" = 1 ]; then
    log "Sign, notarize and staple DMG"
    codesign --force --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$DMG"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl -a -vv -t open --context context:primary-signature "$DMG"
fi

log "Verify DMG contents"
hdiutil verify -quiet "$DMG" || die "hdiutil verify failed"
MNT="$(mktemp -d)"
cleanup_mount() { hdiutil detach -quiet "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup_mount EXIT
hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$MNT" "$DMG"
APPS=("$MNT"/*.app)
[ "${#APPS[@]}" = 1 ] && [ -d "${APPS[0]}" ] || die "DMG must contain exactly one .app"
verify_app "${APPS[0]}" "app in DMG"
cleanup_mount
trap - EXIT

if [ "$DEVELOPER_ID" = 0 ]; then
    log "Ad-hoc build: skipping spctl/stapler (Gatekeeper rejects ad-hoc apps; first launch needs right-click → Open)"
fi

# ---------------------------------------------------------------------------------------------
log "Release artifacts → $OUT"
DMG_COUNT="$(find "$OUT" -maxdepth 1 -name '*.dmg' | wc -l | tr -d ' ')"
[ "$DMG_COUNT" = 1 ] || die "expected exactly one .dmg in $OUT, found $DMG_COUNT"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
(cd "$OUT" && shasum -a 256 "$DMG_NAME" > SHA256SUMS)

NOTES="$OUT/release-notes.md"
if [ -n "$NOTES_FILE" ]; then
    cp "$NOTES_FILE" "$NOTES"
else
    {
        echo "## Changes"
        echo
        if [ -n "$PREV_TAG" ] && [ "$PREV_TAG" != "$TAG" ]; then
            git log --no-merges --format='- %s' "$PREV_TAG..HEAD" | grep -v '^- chore: release ' || true
        else
            git log --no-merges -20 --format='- %s'
        fi
        echo
        echo "**Install:** open the DMG and drag *${DISPLAY_NAME}* to Applications."
        if [ "$DEVELOPER_ID" = 0 ]; then
            echo "The app is ad-hoc signed — on first launch right-click it and choose **Open**."
        fi
        echo
        echo "SHA-256 \`$DMG_NAME\`: \`$SHA\`"
    } > "$NOTES"
fi
ls -l "$OUT"
log "SHA-256 $SHA"

if [ "$DRY_RUN" = 1 ]; then
    log "Dry run complete — nothing was tagged, pushed or published."
    exit 0
fi

# ---------------------------------------------------------------------------------------------
log "Tag $TAG"
if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    git tag -a "$TAG" -m "$DISPLAY_NAME $VERSION"
fi
git push origin "refs/tags/$TAG"

if [ "$RESUME_DRAFT" = 1 ]; then
    log "Update draft release $TAG"
    # Keep exactly one .dmg: drop stale ones with another name, then replace ours.
    while IFS= read -r name; do
        [ "$name" = "$DMG_NAME" ] || gh release delete-asset "$TAG" "$name" -R "$REPO" -y
    done < <(gh release view "$TAG" -R "$REPO" --json assets --jq '.assets[].name | select(endswith(".dmg"))')
    gh release upload "$TAG" "$DMG" -R "$REPO" --clobber
    gh release edit "$TAG" -R "$REPO" --notes-file "$NOTES" --title "$TAG"
else
    log "Create GitHub release $TAG"
    gh release create "$TAG" "$DMG" -R "$REPO" --verify-tag --title "$TAG" --notes-file "$NOTES" --draft
fi

# Verify the uploaded asset before anyone's updater can see the release.
log "Verify uploaded asset"
REMOTE_DMGS="$(gh release view "$TAG" -R "$REPO" --json assets --jq '[.assets[] | select(.name | endswith(".dmg"))] | length')"
[ "$REMOTE_DMGS" = 1 ] || die "release has $REMOTE_DMGS .dmg assets, expected 1"
# On a 404 (drafts) `gh api` prints the error body to stdout, so discard the output on failure.
REMOTE_DIGEST="$(gh api "repos/$REPO/releases/tags/$TAG" --jq '.assets[] | select(.name | endswith(".dmg")) | .digest' 2>/dev/null)" \
    || REMOTE_DIGEST=""
if [ -z "$REMOTE_DIGEST" ]; then
    # Draft releases are not reachable via /releases/tags; look it up in the list.
    REMOTE_DIGEST="$(gh api "repos/$REPO/releases" --jq ".[] | select(.tag_name == \"$TAG\") | .assets[] | select(.name | endswith(\".dmg\")) | .digest")"
fi
[ "$REMOTE_DIGEST" = "sha256:$SHA" ] || die "GitHub digest '$REMOTE_DIGEST' does not match local sha256:$SHA"

if [ "$DRAFT" = 1 ]; then
    log "Left as draft (--draft). Publish later with: gh release edit $TAG -R $REPO --draft=false --latest"
else
    log "Publish $TAG as latest"
    gh release edit "$TAG" -R "$REPO" --draft=false --prerelease=false --latest
    STATE="$(gh release view "$TAG" -R "$REPO" --json isDraft,isPrerelease --jq '"\(.isDraft) \(.isPrerelease)"')"
    [ "$STATE" = "false false" ] || die "release state is '$STATE' (draft prerelease), expected published"
    LATEST="$(gh api "repos/$REPO/releases/latest" --jq .tag_name)"
    [ "$LATEST" = "$TAG" ] || die "releases/latest is $LATEST, not $TAG"
fi

log "Done: https://github.com/$REPO/releases/tag/$TAG"
