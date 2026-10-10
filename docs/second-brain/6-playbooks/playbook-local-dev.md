---
title: "Playbook: local-dev"
type: playbook
updated: 2026-06-05
tags: [playbook, dev-workflow, setup]
---

# Playbook: local-dev — run and debug locally

> Environment bootstrap, file paths, pitfalls specific to a macOS menu-bar app.
> The canonical build description is in `README.md`; this playbook is a shortcut + a list of pitfalls.

## Requirements
- macOS 13+ (`Package.swift` → `.macOS(.v13)`)
- Swift toolchain 5.9+ / Xcode 15+
- A paired BT audio device (for a real disconnect test)

## Steps

| # | Step | Command / where |
|---|---|---|
| 1 | Quick compile (sanity) | `swift build` |
| 2 | Full bundle (for permission tests) | `./scripts/build-app.sh` → `build/BT Audio Idle.app` |
| 3 | Install (login item / notifications require /Applications) | `mv "build/BT Audio Idle.app" /Applications/` |
| 4 | Launch | `open "/Applications/BT Audio Idle.app"` |
| 5 | Watch logs live | `tail -f ~/Library/Logs/BTAudioIdleDisconnect.log` |
| 6 | View / edit settings | `~/Library/Application Support/BTAudioIdleDisconnect/settings.json` |

## State files

| File | Contents |
|---|---|
| `~/Library/Application Support/BTAudioIdleDisconnect/settings.json` | all settings (devices, apps, timeouts), `SettingsStore.swift` |
| `~/Library/Logs/BTAudioIdleDisconnect.log` | logs, rotated at 1 MB → `.log.1`, `AppLogger.swift:47` |

## What people ACTUALLY forget (project-specific)

1. **`swift run` is not suitable for testing notifications or the login item**: `UNUserNotificationCenter`
   and `SMAppService.mainApp` require a signed `.app` bundle in a stable location
   (`/Applications`). A bare executable silently ignores them. Always use `build-app.sh`.
2. **The default timeouts are 10 min / 30 s grace** (`SettingsStore.swift:18`). For iteration,
   shorten `globalTimeoutSeconds` and `preDisconnectGraceSeconds` in `settings.json`, otherwise
   you wait forever.
3. **The app is `.accessory` / `LSUIElement`** (`main.swift:6`, Info.plist), so it has no Dock window.
   "I can't see a window" is not a bug; the icon is in the menu bar.
4. **Gatekeeper** on first launch (ad-hoc signing): right-click → **Open**.
5. **Audio detection works only on the default output**: test by switching the system
   default output to BT, not by writing to another device.

## Related
[[playbook-build-release]] · [[architecture]] · [[moc-codebase]] · [[commands/bug-triage|/bug-triage]]
