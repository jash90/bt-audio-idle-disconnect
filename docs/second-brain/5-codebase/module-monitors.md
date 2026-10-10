---
title: "Module: monitors"
type: module-map
module: monitors
updated: 2026-06-05
tags: [codebase, module]
---

# Module: monitors — observing input signals

> Three independent monitors that feed [[module-orchestration]] with signals:
> is audio playing, is a whitelisted app running, is the system going to sleep/waking up.
> 3 files, ~150 LOC. Each has a callback and a `start()` method (except the polling-only one).

## Code map

- **`AudioMonitor.swift`** (`start()` + listeners): CoreAudio
  `kAudioDevicePropertyDeviceIsRunningSomewhere` on the **default output** +
  a listener for default device changes (`AudioMonitor.swift:53`). Callback
  `onStateChange((Bool) -> Void)`. Emits the initial state (`hasEmittedInitial`).
- **`AppRunningMonitor.swift`** (polling): `NSWorkspace.runningApplications`;
  `isAnyRunning(bundleIds:)` (l. 13) used by the whitelist; `allRunningApps()` for the UI.
- **`SleepWakeMonitor.swift`** (observer): `NSWorkspace.willSleep/didWake`,
  `onSleep`/`onWake` callbacks, cleanup in `deinit`.

## How to extend

- New monitor → [[playbook-new-monitor]] / [[commands/new-monitor|/new-monitor]]
  (full list of registration points in `AppDelegate`).
- Pick a pattern: observer (SleepWake), polling (AppRunning), CoreAudio (Audio).

## Common bugs

- **Confirmed** (from README "Limitations"):
  - Audio is detected **only on the default output**; an app writing to another device
    escapes detection (`AudioMonitor.swift:70`). See [[known-issues]].
  - The whitelist only checks **whether the process exists**, not actual audio use
    (`AppRunningMonitor.swift:13`). See [[known-issues]].
- *Hypotheses (verify):*
  - Changing the default output during silence: a new listener is registered in
    `registerDeviceListener` (l. 60-65); the old listener is not explicitly removed.

## Related
[[moc-codebase]] · [[module-orchestration]] · [[known-issues]]
