---
title: "Playbook: bug-fix"
type: playbook
updated: 2026-06-05
tags: [playbook, dev-workflow, debug]
---

# Playbook: bug-fix — fixing a bug (reading version)

> Executable version: [[commands/bug-triage|/bug-triage]], which runs the same algorithm.
> This is the mental map + pitfalls specific to this app.

## Mental flow (where to look)

The chain of events to trace in the log:

```
AudioMonitor.checkState        → audio playing / silence
  → IdleController.audioPlaybackChanged
    → startIdleTimerIfNeeded    (checks: monitored devices? whitelist? timeout)
      → scheduleIdleFire
        → beginGracePeriod      (notification + grace timer)
          → disconnectMonitoredDevices
            → BluetoothManager.disconnect → closeConnection()
```
A missing line in the log tells you at which link the chain breaks.

## Steps

| # | Step | Where the truth is |
|---|---|---|
| 1 | Check [[known-issues]]: it may be by design, not a bug | `known-issues.md` |
| 2 | Reproduce on a built bundle + `tail -f` the log | [[playbook-local-dev]] |
| 3 | Map symptom → module (table in the command) | [[commands/bug-triage|/bug-triage]] |
| 4 | Shorten the timeouts in `settings.json` so you do not wait 10 min | `SettingsStore.swift:18` |
| 5 | Fix → rebuild → confirm the missing line in the log | `build-app.sh` |
| 6 | Add the confirmed gotcha to the module note | `5-codebase/module-*.md` |

## What people ACTUALLY forget

1. **Testing with a bare `swift run`** instead of the bundle: notifications/login item will not fire,
   it looks like an app bug but it is missing permissions (see [[playbook-local-dev]]).
2. **The `IOReturn` from `closeConnection()` is logged** (`BluetoothManager.swift:46`): if it is
   ≠ `kIOReturnSuccess`, it is a BT stack/permissions problem, not idle logic.
3. **macOS auto-reconnect** looks like "it did not disconnect"; check the log: if there is
   `Disconnect … IOReturn=0` and the device came back, the system reconnected it.

## Related
[[commands/bug-triage|/bug-triage]] · [[known-issues]] · [[module-orchestration]] · [[architecture]]
