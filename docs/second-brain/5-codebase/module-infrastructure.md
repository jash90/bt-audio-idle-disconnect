---
title: "Module: infrastructure"
type: module-map
module: infrastructure
updated: 2026-06-05
tags: [codebase, module]
---

# Module: infrastructure — settings, log, notifications, login item

> Four independent system services (mostly singletons). 4 files, ~289 LOC.

## Code map

- **`SettingsStore.swift`** (98 LOC): `GlobalSettings` (Codable) ↔ `settings.json`
  in Application Support. `@Published settings` with a **debounced save** (0.25 s,
  `scheduleSave` l. 53). Helpers: `effectiveTimeout` (l. 88), `isMonitored` (l. 95),
  per-device upsert/enable/timeout.
- **`AppLogger.swift`** (60 LOC): singleton, queue, ISO8601 → file
  `~/Library/Logs/BTAudioIdleDisconnect.log` + stderr; **rotated at 1 MB** → `.log.1`
  (`rotateIfNeeded` l. 47). Static `info/warn/error/debug`.
- **`NotificationManager.swift`** (88 LOC): `UNUserNotificationCenter`, a category with a
  **Cancel** action, `bootstrap()` (auth + category), `sendPreDisconnect`; the delegate handles the
  Cancel tap → `onCancelTapped`.
- **`LoginItemManager.swift`** (40 LOC): `SMAppService.mainApp` register/unregister +
  `statusDescription`.

## How to extend

- New setting → a field in `GlobalSettings` (l. 17) **with a default value** (otherwise
  old JSON will not decode, l. 45) → Codable saves it automatically.
- New notification type → another `UNNotificationCategory`/action in `bootstrap()`.

## Common bugs

- **Confirmed** (README "Limitations"):
  - `SMAppService.mainApp` requires the `.app` in a stable location (`/Applications`);
    enabling it the first time may need approval in System Settings (`LoginItemManager.swift:17`).
    See [[known-issues]], [[adr-001-ad-hoc-signing]].
- *Hypotheses (verify):*
  - Debounced save (0.25 s): quitting the process right after a change may lose the last write
    (`SettingsStore.swift:53`).
  - No default on a new `GlobalSettings` field → silent reset to defaults on decode.

## Related
[[moc-codebase]] · [[module-orchestration]] · [[module-ui]] · [[known-issues]] · [[adr-001-ad-hoc-signing]]
