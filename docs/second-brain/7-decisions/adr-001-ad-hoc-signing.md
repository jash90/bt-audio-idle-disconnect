---
title: "ADR-001: Ad-hoc signing of the bundle in the build script"
type: adr
status: accepted
updated: 2026-10-10
tags: [adr, build, distribution, security]
---

# ADR-001: Sign the bundle ad-hoc (`codesign --sign -`) in build-app.sh

- **Status**: accepted
- **Source**: `scripts/build-app.sh:27` (`codesign --force --deep --options runtime --sign -`)

## Context
`UNUserNotificationCenter` (the notification with the Cancel action) and `SMAppService.mainApp`
(launch at login) **require a signed bundle** with the hardened runtime
enabled. An unsigned executable (`swift run`) or an unsigned bundle silently ignores
these APIs, so the features look broken. The project has no paid Developer ID at the MVP stage.

## Decision
The `build-app.sh` script always performs an **ad-hoc** codesign (`--sign -`, identity
"-") with `--options runtime` after assembling the bundle, before it goes to `/Applications`.

## Rejected alternatives
- **No signature**: notifications and the login item do not work; the app's main features are dead.
- **Full Developer ID + notarization in the local build**: requires a paid account and
  setup; overkill for local dev/MVP. It remains a step for public distribution.

## Consequences
- ✅ Notifications and `SMAppService` work locally without a paid account.
- ⚠️ An ad-hoc signature does not pass Gatekeeper out of the box; on the recipient's Mac the first launch
  requires right-click → **Open** (documented in [[playbook-build-release]]).
- ⚠️ Public distribution still needs notarization on top.
- ℹ️ Note (2026-10-10): `scripts/release.sh --developer-id` now exists as an opt-in path
  (signs with `APPLE_SIGNING_IDENTITY`, notarizes and staples via `NOTARY_PROFILE`).
  Ad-hoc remains the default; switching the default to Developer ID would need a new ADR
  that supersedes this one.

## Related
[[playbook-build-release]] · [[module-support]] · [[module-infrastructure]] · [[known-issues]]
