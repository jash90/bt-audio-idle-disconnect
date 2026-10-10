---
title: "Playbook: new-monitor"
type: playbook
updated: 2026-06-05
tags: [playbook, dev-workflow, scaffold]
---

# Playbook: new-monitor — add a new monitor (reading version)

> Executable version: [[commands/new-monitor|/new-monitor]]. The most common way of
> extending this app: a new signal source that affects the idle timer.

## Patterns to copy

| Monitor type | Pattern | Note |
|---|---|---|
| Observer / system notification | `SleepWakeMonitor.swift` | `addObserver` + `deinit` with `removeObserver` |
| Polling / on-demand query | `AppRunningMonitor.swift` | pure methods, no state |
| CoreAudio property listener | `AudioMonitor.swift` | `AudioObjectAddPropertyListenerBlock` |

## Steps — registration points (these get forgotten!)

| # | Step | Where |
|---|---|---|
| 1 | New file `<Name>.swift`, `final class`, callback + `start()` | `Sources/BTAudioIdleDisconnect/` |
| 2 | `private let` instance in AppDelegate | `AppDelegate.swift:6-10` |
| 3 | Wire the callback to `idleController.…` | `AppDelegate.swift:33-40` |
| 4 | Call `<name>.start()` | `AppDelegate.swift` (next to `audioMonitor.start()`) |
| 5 | (if needed) a new reaction method calling `onStateChange?()` | `IdleController.swift` |
| 6 | (optional) a field in `GlobalSettings` with a default value | `SettingsStore.swift:17` |
| 7 | (optional) UI in Preferences | `SettingsWindow.swift` |

## What people ACTUALLY forget

1. **A missed `start()`**: the instance exists, the callback is wired, but the monitor never
   started. The most common silent bug.
2. **No default value on a new `GlobalSettings` field** → an old `settings.json`
   will not decode and `SettingsStore` silently loads the defaults (`SettingsStore.swift:45`).
   Codable requires the new field to have a default (`= …`).
3. **A reaction without `onStateChange?()`**: the menu bar UI will not refresh the countdown.

## Related
[[commands/new-monitor|/new-monitor]] · [[module-monitors]] · [[module-orchestration]]
