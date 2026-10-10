---
title: "MOC: Codebase"
type: moc
updated: 2026-06-05
tags: [codebase, map, moc]
---

# MOC — BT Audio Idle Disconnect code map

macOS menu-bar app (Swift, SwiftPM, executable target). 13 `.swift` files
(~1423 LOC), 2 build scripts, 2 resources. A single flat package:
`Sources/BTAudioIdleDisconnect/`.

## Unit definition (coverage contract)

This is a **flat package**, so the unit is a **role group**, not a single file.
6 groups → 6 `module-*.md` notes. Rule: **every** source file, script and resource
has a row in the table below, mapped to a group. A missing row = a silent gap (a
`/sync-code` failure).

## Groups (units)

| Group | Note | Size | Role |
|---|---|---|---|
| bootstrap | [[module-bootstrap]] | 2 files (~53 LOC) | process start, dependency wiring |
| monitors | [[module-monitors]] | 3 files (~150 LOC) | signal observation (audio, apps, sleep) |
| bluetooth | [[module-bluetooth]] | 1 file (56 LOC) | listing + disconnecting BT devices |
| orchestration | [[module-orchestration]] | 1 file (203 LOC) | idle → grace → disconnect logic, snooze |
| ui | [[module-ui]] | 2 files (~592 LOC) | menu bar + Preferences window |
| infrastructure | [[module-infrastructure]] | 4 files (~289 LOC) | settings, log, notifications, login item |
| support | [[module-support]] | 2 scripts + 2 resources | build/DMG, Info.plist, icon |

## File → group (full coverage: 13 .swift + 2 .sh + 2 res)

| File | Group |
|---|---|
| `main.swift` | [[module-bootstrap]] |
| `AppDelegate.swift` | [[module-bootstrap]] |
| `AudioMonitor.swift` | [[module-monitors]] |
| `AppRunningMonitor.swift` | [[module-monitors]] |
| `SleepWakeMonitor.swift` | [[module-monitors]] |
| `BluetoothManager.swift` | [[module-bluetooth]] |
| `IdleController.swift` | [[module-orchestration]] |
| `MenuBarController.swift` | [[module-ui]] |
| `SettingsWindow.swift` | [[module-ui]] |
| `SettingsStore.swift` | [[module-infrastructure]] |
| `AppLogger.swift` | [[module-infrastructure]] |
| `NotificationManager.swift` | [[module-infrastructure]] |
| `LoginItemManager.swift` | [[module-infrastructure]] |
| `scripts/build-app.sh` | [[module-support]] |
| `scripts/build-dmg.sh` | [[module-support]] |
| `Resources/Info.plist` | [[module-support]] |
| `Resources/AppIcon.icns` | [[module-support]] |

## Cross-cutting
[[architecture]] · [[known-issues]] · [[home]]
