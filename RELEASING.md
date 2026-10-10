# Releasing BT Audio Idle

Releases are built, verified and published **from a Mac**, with one command. There is no hosted
build/release workflow: macOS GitHub Actions minutes are billed at 10x, and the whole pipeline takes
about a minute locally.

```bash
scripts/bump-version.sh 1.3.0      # bump CFBundleShortVersionString + CFBundleVersion, commit
git push origin main               # (via a PR if main is protected)
scripts/release.sh --dry-run       # optional rehearsal: builds into dist/release/v1.3.0/
scripts/release.sh                 # tag, build, verify, publish as the latest release
```

## One-time machine setup

| What | Why | How |
|------|-----|-----|
| Xcode 15+ (or a Swift 5.9+ toolchain) | `swift build`, `codesign`, `hdiutil` | App Store / `xcode-select --install` |
| GitHub CLI logged in | tag push + `gh release` | `brew install gh && gh auth login` |
| shellcheck (optional) | `scripts/ci.sh` lints the scripts when present | `brew install shellcheck` |
| Pre-push hook (optional) | runs `scripts/ci.sh` before every `git push` | `git config core.hooksPath .githooks` |

Only for `--developer-id` (see [Signing](#signing)):

| Variable | Meaning | Where it lives |
|----------|---------|----------------|
| `APPLE_SIGNING_IDENTITY` | SHA-1 of the *Developer ID Application* certificate. Always the SHA-1, never the name — two identical certificates exist in the keychain. | `~/.config/local-release/apple.env` (sourced automatically) |
| `APPLE_TEAM_ID` | Team ID the signature must carry | same file |
| `NOTARY_PROFILE` | `xcrun notarytool` keychain profile | same file; create with `xcrun notarytool store-credentials local-release --apple-id … --team-id …` |

No secret is stored in this repository.

## The scripts

### `scripts/ci.sh`

What CI would run: `bash -n` (+ `shellcheck` if installed) on `scripts/*.sh` and `.githooks/*`,
`plutil -lint` on every `.plist`/`.strings` under `Resources/`, `swift build`, `swift test`.

### `scripts/bump-version.sh X.Y.Z [--build N] [--no-commit]`

`Resources/Info.plist` is the only version file. The script sets `CFBundleShortVersionString` to
`X.Y.Z`, raises `CFBundleVersion` by one (or to `N`), refuses to go backwards, re-reads both values
and commits `chore: release X.Y.Z`. It never tags or pushes.

### `scripts/release.sh [--dry-run] [--draft] [--skip-ci] [--developer-id] [--notes FILE]`

1. **Preflight** — required tools; clean working tree; on `main` and equal to `origin/main`; tag
   `vX.Y.Z` absent locally and on GitHub; version is `X.Y.Z`, `CFBundleVersion` is an integer greater
   than the previous tag's; bundle id is still `com.bartlomiejzimny.btaudioidle`; ≥ 3 GB free disk.
   With `--dry-run` the git-state checks only warn, so you can rehearse on a branch or the current version.
2. **CI** — `scripts/ci.sh` (skip with `--skip-ci`).
3. **Build** — `scripts/build-app.sh` (release build, `build/BT Audio Idle.app`, hardened runtime).
4. **Sign** — ad-hoc by default; Developer ID with `--developer-id`.
5. **Verify app** — bundle id, version and build match `Info.plist`;
   `codesign --verify --deep --strict`; hardened runtime flag; ad-hoc signature, or for Developer ID
   the `Developer ID Application` authority and `TeamIdentifier=$APPLE_TEAM_ID`.
6. **Notarize + staple** (`--developer-id` only) — the app (zipped with `ditto`) and then the DMG are
   submitted with `xcrun notarytool submit --wait`, stapled, checked with `xcrun stapler validate`
   and `spctl -a -vv`.
7. **DMG** — `scripts/build-dmg.sh` writes `dist/release/vX.Y.Z/BT.Audio.Idle.X.Y.Z.dmg`;
   `hdiutil verify`, then the DMG is mounted read-only and the app inside goes through step 5 again.
8. **Artifacts** — `dist/release/vX.Y.Z/` (gitignored) holds exactly one `.dmg`, `SHA256SUMS` and
   `release-notes.md` (commit subjects since the previous tag, or `--notes FILE`).
   `--dry-run` stops here.
9. **Publish** — annotated tag `vX.Y.Z` pushed to `origin`; `gh release create` as a draft with the
   DMG; the asset's GitHub `sha256:` digest is compared with the local hash; then the release is
   published as non-draft, non-prerelease and **latest**, and `releases/latest` is checked to point at
   it. With `--draft` it stays a draft (publish later with `gh release edit vX.Y.Z --draft=false --latest`).

Re-running after a failure is safe: if a **draft** release for the tag exists (and the tag points at
`HEAD`), the script reuses it, replaces the DMG (`--clobber`, removing other `.dmg` assets) and
publishes. A published release for the version is never touched — bump the version instead.

## The in-app updater contract

`UpdateChecker.swift` reads `https://api.github.com/repos/jash90/bt-audio-idle-disconnect/releases/latest`
and only installs a release when:

- the tag is `vX.Y.Z` and equals the DMG app's `CFBundleShortVersionString`;
- it has exactly one `.dmg` asset, and GitHub reports a `sha256:` digest for it (checked after download);
- the app inside has the same bundle id and passes `codesign --verify --deep --strict`;
- the release is not a draft or prerelease (`/latest` skips those).

`release.sh` enforces every one of these before and after the upload. Never upload a second `.dmg`
to a release, and never publish a release by hand without the DMG produced by the script.

## Signing

Ad-hoc signing is the default by decision
([ADR-001](docs/second-brain/7-decisions/adr-001-ad-hoc-signing.md)): notifications and
`SMAppService` work, no paid account is needed, but users must right-click → **Open** on first launch,
and because an ad-hoc identity is the binary's hash, macOS may ask for notification/Bluetooth
permission again after an update.

`--developer-id` is opt-in and ready to use (certificate and notary profile are set up on this Mac).
It would remove the right-click → Open step and keep a stable code identity across updates. Switching
the default is a product decision (it changes ADR-001); the updater keeps working either way because it
only requires `codesign --verify --deep --strict` to pass, which both ad-hoc and Developer ID
signatures do. Do not add a Team ID check to the updater without first shipping a Developer ID
release, or ad-hoc installs could never update.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `tag vX.Y.Z already exists` | The version was not bumped: `scripts/bump-version.sh X.Y.(Z+1)`. |
| `HEAD is not equal to origin/main` | `git pull --ff-only` (or push your bump commit / merge its PR) first. |
| `GitHub digest … does not match` | The upload was corrupted or replaced; the release is still a draft — re-run the script. |
| Notarization `Invalid` | `xcrun notarytool log <submission-id> --keychain-profile "$NOTARY_PROFILE"`. |
| `signing identity … not found` | Check `security find-identity -v -p codesigning` and the SHA-1 in `apple.env`. |
| Users report the update was not offered | `gh api repos/jash90/bt-audio-idle-disconnect/releases/latest --jq '.tag_name, .assets[].digest'` — must be the new tag with one `sha256:` digest. |

## Manual fallback (no script)

There is intentionally no GitHub Actions release workflow (`pages.yml` only deploys the website).
If `release.sh` itself is broken, the equivalent manual steps on a Mac are:

```bash
scripts/ci.sh
scripts/build-app.sh
DMG_OUT="dist/release/vX.Y.Z/BT.Audio.Idle.X.Y.Z.dmg" scripts/build-dmg.sh
codesign --verify --deep --strict "build/BT Audio Idle.app"
git tag -a vX.Y.Z -m "BT Audio Idle X.Y.Z" && git push origin vX.Y.Z
gh release create vX.Y.Z "dist/release/vX.Y.Z/BT.Audio.Idle.X.Y.Z.dmg" --verify-tag --title vX.Y.Z --notes-file notes.md --latest
gh api repos/jash90/bt-audio-idle-disconnect/releases/latest --jq '.tag_name, .assets[].digest'
```
