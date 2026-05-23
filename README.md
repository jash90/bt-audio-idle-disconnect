# BT Audio Idle Disconnect

Menu bar app dla macOS, która rozłącza sparowane słuchawki / głośniki Bluetooth, gdy nic nie jest odtwarzane przez konfigurowalny czas (domyślnie 10 min) — z opcjonalnym powiadomieniem i przyciskiem "Cancel" tuż przed rozłączeniem.

## Funkcje

- **Wykrywanie ciszy** przez CoreAudio (`kAudioDevicePropertyDeviceIsRunningSomewhere` na domyślnym wyjściu)
- **Per-device settings**: enable/disable monitorowania, własny timeout (override globalnego)
- **Whitelist apek** — jeśli któraś z nich działa, idle timer się nie uruchamia (np. Zoom, Spotify)
- **Pre-disconnect grace** — powiadomienie systemowe z akcją **Cancel** na X sekund przed rozłączeniem
- **Snooze** — kliknięcie Cancel przedłuża monitorowanie o konfigurowalny czas (domyślnie 5 min)
- **Auto-start przy logowaniu** przez `SMAppService.mainApp`
- **Sleep / Wake** — pauzuje timer przy uśpieniu (opcjonalnie: natychmiastowy disconnect)
- **Logi** w `~/Library/Logs/BTAudioIdleDisconnect.log` (rotacja przy 1 MB)
- **Preferencje** (SwiftUI, 4 taby): General / Devices / Apps / About

## Wymagania

- macOS 13+
- Xcode 15+ lub Swift toolchain 5.9+
- Sparowane urządzenie BT audio

## Build

```bash
cd ~/Projects/bt-audio-idle-disconnect
./scripts/build-app.sh
mv "build/BT Audio Idle.app" /Applications/
open "/Applications/BT Audio Idle.app"
```

Pierwsze uruchomienie: Gatekeeper może blokować — prawy klik → **Open**. macOS zapyta o uprawnienie do powiadomień; zgódź się, jeśli chcesz "Cancel" przed rozłączeniem.

## Pliki konfiguracyjne

| Plik | Co tam jest |
|------|-------------|
| `~/Library/Application Support/BTAudioIdleDisconnect/settings.json` | wszystkie ustawienia (devices, apps, timeouts) |
| `~/Library/Logs/BTAudioIdleDisconnect.log` | logi działania, rotacja przy 1 MB → `.log.1` |

## Architektura

```
main.swift                  bootstrap NSApplication (.accessory)
AppDelegate.swift           wiring monitorów i kontrolera

AudioMonitor                CoreAudio listener (default device + isRunning)
BluetoothManager            IOBluetooth: paired list + closeConnection()
AppRunningMonitor           NSWorkspace.runningApplications
SleepWakeMonitor            NSWorkspace.willSleep / didWake
NotificationManager         UNUserNotificationCenter + Cancel action
LoginItemManager            SMAppService.mainApp
SettingsStore               Codable JSON → Application Support, @Published

IdleController              orkiestracja: idle → grace → disconnect, snooze, sleep
MenuBarController           NSStatusItem + dynamiczne menu z countdownem
SettingsWindow              SwiftUI TabView (General / Devices / Apps / About)
AppLogger                   ISO8601 → plik + stderr, rotacja
```

Stan przepływu:

```
audio playing   → timer off
audio silent    → idle timer (per-device min timeout, lub globalny)
timeout fired   → grace period + notification z "Cancel"
grace fired     → IOBluetoothDevice.closeConnection() na wszystkich monitorowanych
Cancel tapped   → snooze (restart idle z innym czasem)
sleep           → pause | disconnect (per ustawienie)
wake            → ponownie evaluate
```

## Ograniczenia

- **`IOBluetooth.closeConnection()`** jest publiczne, ale legacy. Apple nie oferuje sandbox-friendly alternatywy → **w App Store nie przejdzie**. Dystrybucja: direct download + notarization (lub ad-hoc lokalnie).
- **`SMAppService.mainApp`** wymaga, aby aplikacja była .app bundle w `/Applications` (lub innym stabilnym miejscu); pierwsze włączenie może wymagać zatwierdzenia w *System Settings → General → Login Items*.
- **Auto-reconnect macOS**: niektóre urządzenia / wersje systemu próbują reconnectować po rozłączeniu. Jeśli to robi problem — w *Bluetooth → ⓘ przy urządzeniu* wyłącz auto-connect (jeśli twoje urządzenie to wspiera), albo apka rozłączy ponownie po kolejnym timeoucie.
- Wykrywa audio tylko na **domyślnym wyjściu**. App piszący bezpośrednio do innego urządzenia może uciec wykrywaniu.
- Whitelist sprawdza tylko **czy proces apki istnieje** (NSWorkspace) — nie wie, czy apka faktycznie używa audio.

## Co dalej (poza tym scope)

- Ikona aplikacji (.icns) + custom symbole
- Statystyki rozłączeń (history)
- Reguły wg lokalizacji / sieci Wi-Fi
- Sparkle / auto-update
- Tłumaczenia PL/EN
