---
title: "Command /bug-triage"
type: command
updated: 2026-06-05
tags: [command, dev-workflow, debug]
---

# /bug-triage — from symptom to module and fix

> Philosophy: **reproduction first, then hypothesis, then test, fix last.**
> Do not guess the cause from memory; start with the log and a reproduction.

## Syntax
`/bug-triage <symptom description>`

## Algorithm

### Step 1 — Check known-issues
Read [[known-issues]]. Most "weird" behaviour is a known limitation
(legacy `closeConnection`, detection only on the default output, macOS auto-reconnect).
If the symptom matches a known limitation → it is not a bug, it is by design. Note that and stop.

### Step 2 — Reproduction (MANDATORY)
```bash
cd ~/Projects/bt-audio-idle-disconnect
./scripts/build-app.sh
mv "build/BT Audio Idle.app" /Applications/   # if you are testing the login item / notifications
open "/Applications/BT Audio Idle.app"
# watch the log live:
tail -f ~/Library/Logs/BTAudioIdleDisconnect.log
```
The log is the source of truth about the flow: `Idle timer started`, `Grace period started`,
`Disconnect … IOReturn=`, `Whitelisted app running — timer suppressed`. A missing
expected line tells you at which step the chain breaks.

> Note: notifications and `SMAppService` work **only** for a signed bundle in
> `/Applications`. `swift run` (a bare executable) will not reproduce these symptoms.

### Step 3 — Symptom → module

| Symptom | Look first at | File(s) |
|---|---|---|
| Device is not disconnected after the timeout | [[module-orchestration]], [[module-bluetooth]] | `IdleController.swift`, `BluetoothManager.swift:45` |
| Disconnects too early / too late / wrong timeout | [[module-orchestration]], [[module-infrastructure]] | `IdleController.swift:119`, `SettingsStore.swift:88` |
| Silence not detected / audio plays but the timer runs | [[module-monitors]] | `AudioMonitor.swift:70` (`checkState`) |
| Whitelist does not block the timer | [[module-monitors]] | `AppRunningMonitor.swift:13` |
| Notification / Cancel button does not work | [[module-infrastructure]] | `NotificationManager.swift`, `IdleController.swift:71` |
| Does not start at login | [[module-infrastructure]] | `LoginItemManager.swift` |
| Settings get lost / are not saved | [[module-infrastructure]] | `SettingsStore.swift:53` (`scheduleSave`) |
| Wrong / missing devices in the menu/Devices | [[module-bluetooth]], [[module-ui]] | `BluetoothManager.swift:51` (`isAudio`), `MenuBarController.swift` |
| Timer does not count down while the menu is open | [[module-ui]] | `MenuBarController.swift:34` (`.common` run loop) |
| Sleep/wake breaks the state | [[module-monitors]], [[module-orchestration]] | `SleepWakeMonitor.swift`, `IdleController.swift:50` |

### Step 4 — Locate the root cause
Open the module note from the table ("How to extend" + "Common bugs" sections) and the listed file.
Check the flow first: `AudioMonitor → IdleController.audioPlaybackChanged →
startIdleTimerIfNeeded → scheduleIdleFire → beginGracePeriod → disconnectMonitoredDevices`.

### Step 5 — Fix
First reproduce minimally (shorten the timeouts in `settings.json` so you do not wait 10 min:
`globalTimeoutSeconds`, `preDisconnectGraceSeconds`). Make the change, rebuild, and confirm
in the log that the missing line now appears.

### Step 6 — Close the loop
- [ ] If the cause was non-obvious → add it to the "Common bugs" section of the right
      module note (with `file:line`, marked **Confirmed**, in English).
- [ ] If it is a new permanent limitation → add it to [[known-issues]].
- [ ] If a non-obvious decision was made → `/adr`.

## Related
[[playbook-bug-fix]] · [[moc-codebase]] · [[known-issues]] · [[architecture]]
