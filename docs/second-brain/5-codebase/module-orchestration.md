---
title: "Module: orchestration"
type: module-map
module: orchestration
updated: 2026-06-05
tags: [codebase, module]
---

# Module: orchestration — idle → grace → disconnect logic

> The heart of the app. Ties monitors, settings, notifications and Bluetooth into a state
> machine. 1 file (`IdleController.swift`, 203 LOC). Changes to timer behaviour start here.

## Code map

- **`IdleController.swift`**: state (`isAudioPlaying`, `idleStartedAt`, `inGracePeriod`)
  + 2 timers (`DispatchSourceTimer`: idle, grace).
  - `audioPlaybackChanged(isPlaying:)` (l. 36): playing → stop timers; silence → start.
  - `startIdleTimerIfNeeded()` (l. 102): checks monitored devices? whitelist? computes
    `effectiveTimeout` (min across devices, l. 119).
  - `beginGracePeriod()` (l. 138): grace + notification, then `disconnectMonitoredDevices`.
  - `cancelPendingDisconnect()` (l. 71): snooze (restart idle with a different duration).
  - `systemWillSleep`/`systemDidWake` (l. 50/64), `forceDisconnectNow`, `recomputeMonitoredState`.
  - `remainingSecondsForUI()` (l. 192): countdown for [[module-ui]].

## How to extend

- New reason to block the timer (like the whitelist)? → a guard in `startIdleTimerIfNeeded` (l. 102).
- New way of reacting to a signal? → a public method + `onStateChange?()` at the end (pattern l. 47).
- Changing how the timeout is chosen? → `effectiveTimeout` in [[module-infrastructure]] (`SettingsStore.swift:88`).

## Common bugs

- *Hypotheses (verify in the code):*
  - `effectiveTimeout` takes the **min** across monitored devices (l. 120); several devices
    will disconnect according to the shortest one, which can be surprising.
  - `snooze` only starts when monitored devices are connected (l. 75).
  - Missing `onStateChange?()` after a new state mutation → the UI countdown does not refresh.

## Related
[[moc-codebase]] · [[module-monitors]] · [[module-bluetooth]] · [[module-infrastructure]] · [[architecture]]
