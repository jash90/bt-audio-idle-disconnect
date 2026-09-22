# SITE_NOTES — analiza repozytorium na potrzeby strony GitHub Pages

## Czym jest aplikacja
**BT Audio Idle** (`BTAudioIdleDisconnect`, v1.1.0, bundle `com.bartlomiejzimny.btaudioidle`) to natywna aplikacja
macOS działająca wyłącznie w pasku menu (`LSUIElement`, `.accessory`). Gdy na domyślnym wyjściu audio przez
ustawiony czas nic nie gra (domyślnie 10 min), rozłącza sparowane urządzenia audio Bluetooth. Wcześniej
wysyła powiadomienie z akcją **Cancel**, której kliknięcie odsuwa rozłączenie (snooze).

- **Typ projektu:** aplikacja desktopowa macOS (menu bar), Swift Package, bez testów i bez CI buildu.
- **Odbiorca strony:** użytkownik końcowy Maca ze słuchawkami lub głośnikiem BT. Projekt jest open source,
  więc na stronie jest też krótka sekcja techniczna (build ze źródeł, stack).
- **Język UI:** tylko angielski (brak `.lproj` / `Localizable.strings`, README wymienia „Tłumaczenia PL/EN”
  w sekcji „Co dalej”). Jeden zestaw zrzutów dla obu wersji strony.

## Stack i uruchomienie
- Swift 5.9 / SwiftPM, macOS 13+, frameworki: AppKit, SwiftUI, CoreAudio, IOBluetooth, UserNotifications,
  ServiceManagement (`Package.swift`).
- Build: `./scripts/build-app.sh` → `build/BT Audio Idle.app` (podpis ad-hoc), DMG: `./scripts/build-dmg.sh`.
- Brak zmiennych środowiskowych, bazy i zewnętrznego API. Dane: `~/Library/Application Support/BTAudioIdleDisconnect/settings.json`,
  log: `~/Library/Logs/BTAudioIdleDisconnect.log` (rotacja 1 MB).

## Funkcje (z kodu)
| Obszar | Źródło | Szczegóły |
|---|---|---|
| Wykrywanie ciszy | `AudioMonitor.swift` | `kAudioDevicePropertyDeviceIsRunningSomewhere` na domyślnym wyjściu; odtwarzanie liczy się dopiero po `playbackConfirmSeconds` |
| Orkiestracja | `IdleController.swift` | idle → grace (powiadomienie) → `closeConnection()`; snooze; min. z timeoutów urządzeń; reconnect cooldown; whitelist |
| Ustawienia | `SettingsStore.swift` | timeout 600 s (1–60 min), grace 30 s (0–120), snooze 300 s (1–60 min), confirm 6 s (0–15), cooldown 60 s (0–300), notyfikacje on, dźwięk off, pauza przy uśpieniu on, rozłącz przy uśpieniu off |
| Menu | `MenuBarController.swift` | ikona z odliczaniem m:ss / sekundy w grace; Status, Connected, Cancel timer (snooze), Disconnect now ⌘D, Preferences… ⌘,, Open Log File, Quit ⌘Q |
| Preferencje | `SettingsWindow.swift` | karty General / Devices / Apps / About |
| Powiadomienie | `NotificationManager.swift` | „Disconnecting Bluetooth audio” + „… will be disconnected in Ns. Tap Cancel to keep connected.” |
| Autostart | `LoginItemManager.swift` | `SMAppService.mainApp` |

Ograniczenia (README): legacy `IOBluetooth` = brak App Store, tylko domyślne wyjście, whitelist sprawdza
jedynie, czy proces działa, auto-reconnect niektórych urządzeń.

## Dane do strony
- **Repo:** `jash90/bt-audio-idle-disconnect` (publiczne) → `https://jash90.github.io/bt-audio-idle-disconnect/`, brak `CNAME`.
- **CTA:** brak adresu produkcyjnego i `homepage`; aplikacja jest dystrybuowana jako DMG w GitHub Releases
  → przycisk prowadzi do `releases/latest` (v1.1.0, `BT.Audio.Idle.1.1.0.dmg`), drugi przycisk do repo.
- **Licencja:** brak pliku `LICENSE`. Na stronie jest to napisane wprost.
- **Kontakt:** z karty About w aplikacji: Bartłomiej Zimny, raccoonsoftware.pl, bartlomiejzimny@outlook.com.
- **Identyfikacja wizualna:** kolory z `Resources/AppIcon.icns`: `#0E2A72`, `#1D51A3`, `#35A2D7`, `#C4E2FC`.
  Font: systemowy SF (aplikacja używa fontów systemowych).

## Istniejące rozwiązania
- `/docs` zawiera `second-brain` (dokumentacja deweloperska, nieśledzona w git), więc strona trafiła do `/site`.
- Brak gałęzi `gh-pages` i workflow Pages. Jedyny workflow: `pullfrog.yml` (bez zmian).

## Zrzuty ekranu
- `scripts/screenshots.sh` kompiluje prawdziwe źródła aplikacji z `scripts/screenshots/*.swift`. Te pliki
  zastępują `main.swift`, `BluetoothManager.swift` i `AppRunningMonitor.swift` fikcyjnymi urządzeniami
  i aplikacjami. Proces działa z `CFFIXED_USER_HOME=/Users/demo`, więc nie czyta ani nie nadpisuje
  prawdziwych ustawień i logów, a w karcie About widać ścieżkę `/Users/demo/...`.
- Wynik: 4 karty Preferencji × jasny/ciemny, WebP (11–20 KB każdy).
- Nie zrobiono zrzutów menu w pasku menu ani powiadomienia systemowego: na macOS 26 okna menu i
  powiadomień nie należą do procesu aplikacji, a przechwycenie ich wymagałoby uprawnienia Screen Recording.
  Na stronie są opisane tekstem na podstawie kodu.
- Zrzuty mobilne aplikacji nie mają sensu (aplikacja desktopowa). Wersję mobilną ma sama strona.
