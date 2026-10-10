---
title: "Module: ui"
type: module-map
module: ui
updated: 2026-06-05
tags: [codebase, module]
---

# Module: ui — menu bar and Preferences window

> The entire visible surface: a dynamic menu bar menu (countdown) + a SwiftUI settings
> window (4 tabs). 2 files, ~592 LOC (`SettingsWindow.swift` is the largest file in the repo).

## Code map

- **`MenuBarController.swift`** (185 LOC): `NSStatusItem` + `NSMenu`. Subscribes to
  `idleController.onStateChange`, refreshes every 1 s. **Timer in `.common` mode** (l. 34)
  so the countdown ticks while the menu is open (default-mode timers are paused during
  menu tracking). Builds items from `bluetoothManager` and `idleController.remainingSecondsForUI()`.
- **`SettingsWindow.swift`** (407 LOC): SwiftUI `TabView`: General / Devices / Apps / About.
  Reads/writes through `SettingsStore` (`@Published`), uses `LoginItemManager` (the
  "Launch at login" toggle) and `AppRunningMonitor.allRunningApps()` to pick whitelisted apps.

## How to extend

- New menu item → `MenuBarController` (menu rebuild / `menuNeedsUpdate`).
- New setting in the UI → add a field in `GlobalSettings` ([[module-infrastructure]]),
  then a control in the right tab of `SettingsWindow.swift`.

## Common bugs

- **Confirmed**:
  - The countdown in an open menu requires the `.common` run loop mode (`MenuBarController.swift:34`);
    removing it stops the countdown while the menu is held open.
- *Hypotheses (verify):*
  - The UI does not refresh when a state mutation in `IdleController` does not call `onStateChange?()`.
  - The device/app lists refresh when the menu / window opens; a freshly paired
    device may need a reopen.

## Related
[[moc-codebase]] · [[module-orchestration]] · [[module-infrastructure]] · [[module-bluetooth]]
