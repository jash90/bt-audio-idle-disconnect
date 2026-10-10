---
title: "Known issues — confirmed limitations"
type: reference
updated: 2026-06-05
tags: [codebase, known-issues, gotchas]
---

# Known issues — confirmed limitations and pitfalls

> All **Confirmed** items are rooted in the README ("Limitations") and the code.
> These are not bugs to fix; they are deliberate limitations of the project. Check here **before**
> you start debugging "weird" behaviour.

## Confirmed (design / platform)

| # | Limitation | Source | Impact on debugging |
|---|---|---|---|
| K1 | `IOBluetooth.closeConnection()` is public but **legacy**; no sandbox-friendly alternative → **no App Store** | README; `BluetoothManager.swift:45` | Distribution only via direct download + (ad-hoc/notarization). See [[adr-002-legacy-closeconnection-distribution]] |
| K2 | **macOS auto-reconnect**: some devices/OS versions reconnect after a disconnect | README "Limitations" | The log shows `Disconnect … IOReturn=0` and the device comes back = that is the system, not a bug. The app disconnects again after the next timeout |
| K3 | Audio detection **only on the default output** | README; `AudioMonitor.swift:70` | An app writing to another device escapes silence detection |
| K4 | The whitelist checks **only whether the process exists** (NSWorkspace), not actual audio use | README; `AppRunningMonitor.swift:13` | A whitelisted app in the background (e.g. minimized Spotify) blocks the timer despite silence |
| K5 | `SMAppService.mainApp` requires the `.app` in a stable location; enabling it the first time may need approval in *System Settings → Login Items* | README; `LoginItemManager.swift:17` | "Launch at login does not work" from `build/`/Downloads: move it to `/Applications` |
| K6 | Ad-hoc signing is **required** for notifications and the login item | `build-app.sh:27` | Testing with a bare `swift run`/unsigned bundle → notifications and SMAppService stay silent. See [[adr-001-ad-hoc-signing]] |
| K7 | The app is `LSUIElement`/`.accessory`, so there is no Dock window | `main.swift:6`; Info.plist | "There is no window" is not a bug; the UI is in the menu bar. See [[adr-003-accessory-menu-bar-only]] |

## Hypotheses (verify in the code before relying on them)

- **H1** — Debounced save (0.25 s, `SettingsStore.swift:53`): killing the process right
  after a settings change may lose the last write.
- **H2** — A new field in `GlobalSettings` without a default value → an old `settings.json`
  will not decode and `SettingsStore` silently loads the defaults (`SettingsStore.swift:45`).
- **H3** — `effectiveTimeout` takes the **min** across monitored devices
  (`IdleController.swift:120`); with several devices the disconnect follows the shortest one.
- **H4** — When the default output changes, the old CoreAudio property listener is not
  explicitly unregistered (`AudioMonitor.swift:60`).

## Related
[[architecture]] · [[moc-codebase]] · [[commands/bug-triage|/bug-triage]] · [[adr-001-ad-hoc-signing]] · [[adr-002-legacy-closeconnection-distribution]]
