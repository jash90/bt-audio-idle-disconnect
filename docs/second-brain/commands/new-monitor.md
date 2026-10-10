---
title: "Command /new-monitor"
type: command
updated: 2026-06-05
tags: [command, dev-workflow, scaffold]
---

# /new-monitor — add a new monitor / signal source

> Monitor = a class that observes some source (audio, apps, sleep, network…) and
> calls a callback into [[module-orchestration]]. The value of this command is the **list
> of registration points that are easy to forget**.

## Syntax
`/new-monitor <MonitorName>`  (e.g. `WiFiMonitor`, `PowerSourceMonitor`)

## Algorithm

### Step 1 — Interview
Ask / establish:
- What does it observe and through which API (NSWorkspace? CoreAudio? IOKit?)
- Is it a push signal (listener/observer) or does it need polling?
- How should it affect idle: does it **suspend** the timer (like the whitelist) or **reset** the state
  (like audio playing)?

### Step 2 — Create the monitor file
`Sources/BTAudioIdleDisconnect/<Name>.swift`. Patterns to copy:
- listener-based → [[module-monitors]] `SleepWakeMonitor.swift` (observer + `start()` + `deinit`)
- polling/query → `AppRunningMonitor.swift` (pure query methods)
- CoreAudio property listener → `AudioMonitor.swift`

Convention: `final class`, callback `var onSomething: (() -> Void)?` or
`((Bool) -> Void)?`, a `start()` method. Log events via `AppLogger.info(…)`.

### Step 3 — REGISTRATION POINTS (these get forgotten!)
1. **Instance in `AppDelegate.swift`**: add `private let <name> = <Name>()`
   (pattern: lines 6-10).
2. **Wire the callback in `applicationDidFinishLaunching`**: set `onSomething` so that
   it calls the right `idleController.…` method (pattern: `audioMonitor.onStateChange` /
   `sleepWakeMonitor.onSleep`, lines 33-40).
3. **Call `<name>.start()`** in the same place; without it the monitor is dead.
4. **Reaction method in `IdleController`**: if a new kind of reaction is needed
   (`audioPlaybackChanged` / `recomputeMonitoredState` are not enough), add a public method
   in `IdleController.swift` and make sure it calls `onStateChange?()` at the end.
5. **(optional) On/off setting**: if it should be configurable, add a field to
   `GlobalSettings` in `SettingsStore.swift:17` (Codable → saved to JSON automatically;
   remember a default value so old `settings.json` files still decode).
6. **(optional) UI**: a tab/checkbox in `SettingsWindow.swift`.

### Step 4 — Sanity
```bash
swift build            # quick compile
./scripts/build-app.sh # full bundle for testing with permissions
tail -f ~/Library/Logs/BTAudioIdleDisconnect.log
```
Confirm in the log that `start()` ran and the callback fires when the signal changes.

### Step 5 — Close the loop
- [ ] Add a row for the monitor to the table in [[module-monitors]] and to `moc-codebase` (file → group).
- [ ] If the effect on idle was non-obvious → `/adr`.

## Related
[[module-monitors]] · [[module-orchestration]] · [[playbook-new-monitor]] · [[architecture]]
