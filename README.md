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
- **Aktualizacje z GitHub Releases** — *Check for Updates…* w menu i w zakładce About: wykrywa nowszą wersję, pokazuje release notes, pobiera DMG, weryfikuje SHA-256 i podmienia aplikację z restartem. Opcjonalne automatyczne sprawdzanie raz na dobę (domyślnie włączone)

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
UpdateChecker               GitHub Releases: check → download → SHA-256 → hdiutil → swap + relaunch

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

## Wydanie nowej wersji (release)

Updater w aplikacji czyta `https://api.github.com/repos/jash90/bt-audio-idle-disconnect/releases/latest`, więc każde wydanie musi spełniać:

1. `CFBundleShortVersionString` w `Resources/Info.plist` podbity (np. `1.2.0`), `CFBundleVersion` +1.
2. Tag `vX.Y.Z` **równy** `CFBundleShortVersionString` — updater odrzuca DMG, w którym wersja aplikacji nie zgadza się z tagiem.
3. Dokładnie jeden plik `.dmg` jako asset, zbudowany przez `./scripts/build-dmg.sh`. GitHub sam dodaje do assetu digest SHA-256 — bez niego aktualizacja nie zostanie zainstalowana automatycznie.
4. Release nie może być draftem ani pre-release (`/latest` je pomija).

```bash
./scripts/build-dmg.sh
gh release create v1.2.0 "build/BT Audio Idle 1.2.0.dmg" --title "v1.2.0" --notes-file notes.md
```

Jak działa instalacja: DMG trafia do `~/Library/Caches/BTAudioIdleDisconnect/Updates/`, po weryfikacji SHA-256 jest montowany (`hdiutil`), sprawdzane są bundle id, wersja i `codesign --verify`, a aplikacja jest kopiowana do `staged/`. Następnie odłączony skrypt `install.sh` czeka na zamknięcie aplikacji, podmienia bundle (z przywróceniem starej wersji przy błędzie) i uruchamia ją ponownie. Wpisy `installer:` lądują w zwykłym logu. Jeśli katalog aplikacji nie jest zapisywalny, updater otwiera zweryfikowany DMG do ręcznego przeciągnięcia.

## Ograniczenia

- **`IOBluetooth.closeConnection()`** jest publiczne, ale legacy. Apple nie oferuje sandbox-friendly alternatywy → **w App Store nie przejdzie**. Dystrybucja: direct download + notarization (lub ad-hoc lokalnie).
- **`SMAppService.mainApp`** wymaga, aby aplikacja była .app bundle w `/Applications` (lub innym stabilnym miejscu); pierwsze włączenie może wymagać zatwierdzenia w *System Settings → General → Login Items*.
- **Auto-reconnect macOS**: niektóre urządzenia / wersje systemu próbują reconnectować po rozłączeniu. Jeśli to robi problem — w *Bluetooth → ⓘ przy urządzeniu* wyłącz auto-connect (jeśli twoje urządzenie to wspiera), albo apka rozłączy ponownie po kolejnym timeoucie.
- Wykrywa audio tylko na **domyślnym wyjściu**. App piszący bezpośrednio do innego urządzenia może uciec wykrywaniu.
- Whitelist sprawdza tylko **czy proces apki istnieje** (NSWorkspace) — nie wie, czy apka faktycznie używa audio.
- **Aktualizacje**: wersje ≤ 1.1.0 nie mają updatera — na 1.2.0 trzeba przejść raz ręcznie. Przy podpisie ad-hoc tożsamość aplikacji to hash binarki, więc po aktualizacji macOS może ponownie zapytać o powiadomienia / Bluetooth, a *Launch at login* może wymagać ponownego włączenia. SHA-256 z GitHuba chroni przed uszkodzonym pobraniem, ale nie potwierdza autora (digest pochodzi z tego samego konta) — pełne uwierzytelnienie dałby dopiero Developer ID + notaryzacja.

## Co dalej (poza tym scope)

- Ikona aplikacji (.icns) + custom symbole
- Statystyki rozłączeń (history)
- Reguły wg lokalizacji / sieci Wi-Fi
- Tłumaczenia PL/EN
