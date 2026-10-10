---
title: "Playbook: build-release"
type: playbook
updated: 2026-10-10
tags: [playbook, build, distribution]
---

# Playbook: build-release — bundle, DMG, distribution

> How to build the `.app` and `.dmg` and publish a release. Distribution is **direct download +
> ad-hoc/notarization**; the App Store is out (see [[adr-002-legacy-closeconnection-distribution]]).
> Releases are built locally by scripts; full details live in `RELEASING.md` in the repo root.

## Steps

| # | Step | Command / where |
|---|---|---|
| 1 | Bump the version | `scripts/bump-version.sh X.Y.Z` (bumps `CFBundleShortVersionString` + `CFBundleVersion` in `Resources/Info.plist` and commits) |
| 2 | Rehearse the release | `scripts/release.sh --dry-run` |
| 3 | Build, verify and publish | `scripts/release.sh` (artifacts in `dist/release/vX.Y.Z/`) |
| 4 | (optional) Publish as a draft / skip CI | `scripts/release.sh --draft`, `scripts/release.sh --skip-ci` |
| 5 | (optional, opt-in) Developer ID signing | `scripts/release.sh --developer-id`: signs with `APPLE_SIGNING_IDENTITY`, notarizes and staples via the `NOTARY_PROFILE` keychain profile |

Ad-hoc signing stays the default ([[adr-001-ad-hoc-signing]]); `--developer-id` is an explicit opt-in.
For a plain local build without publishing: `./scripts/build-app.sh` and `./scripts/build-dmg.sh`.

## In-app updater contract (enforced by `release.sh`)

- Tag `vX.Y.Z` **equal** to `CFBundleShortVersionString`; the updater rejects a DMG whose app version does not match the tag.
- Exactly one `.dmg` asset, with the SHA-256 digest that GitHub adds to assets.
- Not a draft and not a pre-release (`/releases/latest` skips them).

## What people ACTUALLY forget (project-specific)

1. **Ad-hoc signing is MANDATORY, not cosmetic**: `build-app.sh:27`
   (`codesign --force --deep --options runtime --sign -`). Without it notifications and
   `SMAppService` will not work for the recipient. See [[adr-001-ad-hoc-signing]].
2. **`SMAppService.mainApp` requires a stable location**: an app launched from `build/`
   or Downloads may not register the login item correctly. Tell users: first
   drag it to `/Applications`, then enable "Launch at login".
3. **The version in the DMG name comes from Info.plist** (`build-dmg.sh:19`, PlistBuddy). Always bump
   with `scripts/bump-version.sh`; a stale plist means a stale DMG name and a tag mismatch.
4. **`build/` and `dist/` are not in git**: artifacts live only in GitHub Releases.
5. Without notarization (the ad-hoc default), Gatekeeper on the recipient's Mac requires right-click → **Open** the
   first time. Document this in the release notes.

## Related
[[playbook-local-dev]] · [[adr-001-ad-hoc-signing]] · [[adr-002-legacy-closeconnection-distribution]] · [[module-support]]
