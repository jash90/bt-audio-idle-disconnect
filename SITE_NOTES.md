# SITE_NOTES — repository analysis for the GitHub Pages site

## What the app is
**BT Audio Idle** (`BTAudioIdleDisconnect`, v1.1.0, bundle `com.bartlomiejzimny.btaudioidle`) is a native
macOS app that lives only in the menu bar (`LSUIElement`, `.accessory`). When nothing has been playing on the default audio
output for the configured time (10 min by default), it disconnects paired Bluetooth audio devices. Before that it
sends a notification with a **Cancel** action; clicking it postpones the disconnect (snooze).

- **Project type:** macOS desktop app (menu bar), Swift Package, no tests and no CI build.
- **Site audience:** an end user of a Mac with BT headphones or a speaker. The project is open source,
  so the site also has a short technical section (building from source, stack).
- **UI language:** English only (no `.lproj` / `Localizable.strings`; the README lists "PL/EN translations"
  under "What's next"). One set of screenshots for both language versions of the site.

## Stack and running
- Swift 5.9 / SwiftPM, macOS 13+, frameworks: AppKit, SwiftUI, CoreAudio, IOBluetooth, UserNotifications,
  ServiceManagement (`Package.swift`).
- Build: `./scripts/build-app.sh` → `build/BT Audio Idle.app` (ad-hoc signature), DMG: `./scripts/build-dmg.sh`.
- No environment variables, database or external API. Data: `~/Library/Application Support/BTAudioIdleDisconnect/settings.json`,
  log: `~/Library/Logs/BTAudioIdleDisconnect.log` (rotated at 1 MB).

## Features (from the code)
| Area | Source | Details |
|---|---|---|
| Silence detection | `AudioMonitor.swift` | `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default output; playback only counts after `playbackConfirmSeconds` |
| Orchestration | `IdleController.swift` | idle → grace (notification) → `closeConnection()`; snooze; min. of device timeouts; reconnect cooldown; whitelist |
| Settings | `SettingsStore.swift` | timeout 600 s (1–60 min), grace 30 s (0–120), snooze 300 s (1–60 min), confirm 6 s (0–15), cooldown 60 s (0–300), notifications on, sound off, pause on sleep on, disconnect on sleep off |
| Menu | `MenuBarController.swift` | icon with an m:ss countdown / seconds during grace; Status, Connected, Cancel timer (snooze), Disconnect now ⌘D, Preferences… ⌘,, Open Log File, Quit ⌘Q |
| Preferences | `SettingsWindow.swift` | General / Devices / Apps / About tabs |
| Notification | `NotificationManager.swift` | "Disconnecting Bluetooth audio" + "… will be disconnected in Ns. Tap Cancel to keep connected." |
| Launch at login | `LoginItemManager.swift` | `SMAppService.mainApp` |

Limitations (README): legacy `IOBluetooth` = no App Store, default output only, the whitelist only checks
whether the process is running, auto-reconnect of some devices.

## Site data
- **Repo:** `jash90/bt-audio-idle-disconnect` (public) → `https://jash90.github.io/bt-audio-idle-disconnect/`, no `CNAME`.
- **CTA:** no production URL and no `homepage`; the app is distributed as a DMG in GitHub Releases
  → the button links to `releases/latest` (v1.1.0, `BT.Audio.Idle.1.1.0.dmg`), a second button to the repo.
- **License:** no `LICENSE` file. The site says so explicitly.
- **Contact:** from the About tab in the app: Bartłomiej Zimny, raccoonsoftware.pl, bartlomiejzimny@outlook.com.
- **Visual identity:** colors from `Resources/AppIcon.icns`: `#0E2A72`, `#1D51A3`, `#35A2D7`, `#C4E2FC`.
  Font: system SF (the app uses system fonts).

## Existing setup
- `/docs` contains `second-brain` (developer documentation, untracked in git), so the site went into `/site`.
- No `gh-pages` branch and no Pages workflow. The only workflow: `pullfrog.yml` (unchanged).

## Screenshots
- `scripts/screenshots.sh` compiles the real app sources with `scripts/screenshots/*.swift`. These files
  replace `main.swift`, `BluetoothManager.swift` and `AppRunningMonitor.swift` with fake devices
  and apps. The process runs with `CFFIXED_USER_HOME=/Users/demo`, so it neither reads nor overwrites
  the real settings and logs, and the About tab shows the `/Users/demo/...` path.
- Output: 4 Preferences tabs × light/dark, WebP (11–20 KB each).
- No screenshots were taken of the menu bar menu or the system notification: on macOS 26 the menu and
  notification windows do not belong to the app's process, and capturing them would require the Screen Recording permission.
  The site describes them in text based on the code.
- Mobile screenshots of the app make no sense (it is a desktop app). The site itself has a mobile version.
