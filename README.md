**English** · [Polski](README.pl.md)

# BT Audio Idle Disconnect

A macOS menu bar app that disconnects paired Bluetooth headphones / speakers when nothing has been playing for a configurable time (10 min by default), with an optional notification and a "Cancel" button right before the disconnect.

## Features

- **Silence detection** via CoreAudio (`kAudioDevicePropertyDeviceIsRunningSomewhere` on the default output)
- **Per-device settings**: enable/disable monitoring, custom timeout (overrides the global one)
- **App whitelist**: if any of these apps is running, the idle timer does not start (e.g. Zoom, Spotify)
- **Pre-disconnect grace**: a system notification with a **Cancel** action X seconds before the disconnect
- **Snooze**: clicking Cancel extends monitoring by a configurable time (5 min by default)
- **Launch at login** via `SMAppService.mainApp`
- **Sleep / Wake**: pauses the timer on sleep (optionally: disconnect immediately)
- **Logs** in `~/Library/Logs/BTAudioIdleDisconnect.log` (rotated at 1 MB)
- **Preferences** (SwiftUI, 4 tabs): General / Devices / Apps / About
- **Updates from GitHub Releases**: *Check for Updates…* in the menu and in the About tab detects a newer version, shows the release notes, downloads the DMG, verifies SHA-256 and replaces the app with a relaunch. Optional automatic check once a day (on by default)
- **UI in English and Polish** (follows the macOS language)

## Requirements

- macOS 13+
- Xcode 15+ or Swift toolchain 5.9+
- A paired Bluetooth audio device

## Build

```bash
cd ~/Projects/bt-audio-idle-disconnect
./scripts/build-app.sh
mv "build/BT Audio Idle.app" /Applications/
open "/Applications/BT Audio Idle.app"
```

First launch: Gatekeeper may block the app. Right-click → **Open**. macOS will ask for notification permission; allow it if you want the "Cancel" prompt before a disconnect.

## Configuration files

| File | Contents |
|------|----------|
| `~/Library/Application Support/BTAudioIdleDisconnect/settings.json` | all settings (devices, apps, timeouts) |
| `~/Library/Logs/BTAudioIdleDisconnect.log` | runtime logs, rotated at 1 MB → `.log.1` |

## Architecture

```
main.swift                  NSApplication bootstrap (.accessory)
AppDelegate.swift           wiring of monitors and the controller

AudioMonitor                CoreAudio listener (default device + isRunning)
BluetoothManager            IOBluetooth: paired list + closeConnection()
AppRunningMonitor           NSWorkspace.runningApplications
SleepWakeMonitor            NSWorkspace.willSleep / didWake
NotificationManager         UNUserNotificationCenter + Cancel action
LoginItemManager            SMAppService.mainApp
SettingsStore               Codable JSON → Application Support, @Published
UpdateChecker               GitHub Releases: check → download → SHA-256 → hdiutil → swap + relaunch

IdleController              orchestration: idle → grace → disconnect, snooze, sleep
MenuBarController           NSStatusItem + dynamic menu with a countdown
SettingsWindow              SwiftUI TabView (General / Devices / Apps / About)
AppLogger                   ISO8601 → file + stderr, rotation
```

Flow states:

```
audio playing   → timer off
audio silent    → idle timer (minimum per-device timeout, or the global one)
timeout fired   → grace period + notification with "Cancel"
grace fired     → IOBluetoothDevice.closeConnection() on all monitored devices
Cancel tapped   → snooze (restart idle with a different duration)
sleep           → pause | disconnect (per setting)
wake            → evaluate again
```

## Development

`scripts/ci.sh` builds the app and runs the tests. Optional pre-push hook: `git config core.hooksPath .githooks`.

## Releasing a new version

Releases are built locally: `scripts/bump-version.sh X.Y.Z`, then `scripts/release.sh` (rehearse with `scripts/release.sh --dry-run`).

A release must satisfy the in-app updater contract: tag `vX.Y.Z` equal to `CFBundleShortVersionString`, exactly one `.dmg` asset with a GitHub SHA-256 digest, and not a draft or pre-release. `release.sh` enforces this. See [RELEASING.md](RELEASING.md) for details.

How installation works: the DMG is downloaded to `~/Library/Caches/BTAudioIdleDisconnect/Updates/`, mounted (`hdiutil`) after SHA-256 verification, the bundle id, version and `codesign --verify` are checked, and the app is copied to `staged/`. A detached `install.sh` script then waits for the app to quit, swaps the bundle (restoring the old version on failure) and relaunches it. `installer:` entries go to the regular log. If the app's directory is not writable, the updater opens the verified DMG for a manual drag-and-drop.

## Limitations

- **`IOBluetooth.closeConnection()`** is public but legacy. Apple offers no sandbox-friendly alternative → **it will not pass App Store review**. Distribution: direct download + notarization (or ad-hoc locally).
- **`SMAppService.mainApp`** requires the app to be a .app bundle in `/Applications` (or another stable location); enabling it for the first time may require approval in *System Settings → General → Login Items*.
- **macOS auto-reconnect**: some devices / OS versions try to reconnect after a disconnect. If that is a problem, turn off auto-connect in *Bluetooth → ⓘ next to the device* (if your device supports it), otherwise the app will disconnect again after the next timeout.
- Audio is detected only on the **default output**. An app writing directly to another device can escape detection.
- The whitelist only checks **whether the app's process exists** (NSWorkspace); it does not know whether the app is actually using audio.
- **Updates**: versions ≤ 1.1.0 have no updater, so moving to 1.2.0 has to be done manually once. With ad-hoc signing the app's identity is the binary hash, so after an update macOS may ask again for notification / Bluetooth permissions, and *Launch at login* may need to be re-enabled. The SHA-256 digest from GitHub protects against a corrupted download but does not authenticate the author (the digest comes from the same account); full authentication would require Developer ID + notarization.

## What's next (out of scope)

- App icon (.icns) + custom symbols
- Disconnect statistics (history)
- Rules by location / Wi-Fi network
