import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let idleController: IdleController
    private let bluetoothManager: BluetoothManager
    private let settings: SettingsStore

    private let menu = NSMenu()
    private var statusLineItem: NSMenuItem?
    private var settingsWindowController: SettingsWindowController?
    private var refreshTimer: Timer?

    init(
        idleController: IdleController,
        bluetoothManager: BluetoothManager,
        settings: SettingsStore
    ) {
        self.idleController = idleController
        self.bluetoothManager = bluetoothManager
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu

        idleController.onStateChange = { [weak self] in
            DispatchQueue.main.async { self?.tick() }
        }

        // Use .common run loop mode so the countdown keeps ticking while the
        // menu is open (default-mode timers are paused during menu tracking).
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        rebuildMenu()
        configureButton()
    }

    /// Cheap per-second update: refresh the menu bar button and the visible
    /// status line in place, without rebuilding the whole menu.
    private func tick() {
        configureButton()
        statusLineItem?.title = statusText()
    }

    /// Full structural rebuild — runs right before the menu is shown so the
    /// connected-device list and item states are fresh on every open.
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let symbol: String
        var title = ""

        if idleController.inGracePeriod {
            symbol = "headphones.circle.fill"
            title = " \(Int(idleController.remainingSecondsForUI()))s"
        } else if idleController.isAudioPlaying {
            symbol = "headphones.circle"
        } else if idleController.idleStartedAt != nil {
            symbol = "headphones"
            let r = Int(idleController.remainingSecondsForUI())
            title = String(format: " %d:%02d", r / 60, r % 60)
        } else {
            symbol = "headphones"
        }

        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "BT Audio Idle")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeft
        button.title = title
        // monospaced digits so the bar width doesn't jitter as the countdown ticks
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    private func statusText() -> String {
        if idleController.isAudioPlaying {
            return "Status: playing"
        } else if idleController.inGracePeriod {
            let remaining = Int(idleController.remainingSecondsForUI())
            return "Status: disconnecting in \(remaining)s"
        } else if idleController.idleStartedAt != nil {
            let remaining = idleController.remainingSecondsForUI()
            let mins = Int(remaining) / 60
            let secs = Int(remaining) % 60
            return String(format: "Status: idle — %d:%02d remaining", mins, secs)
        } else {
            return "Status: idle"
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let statusLine = disabled(statusText())
        statusLineItem = statusLine
        menu.addItem(statusLine)

        let connectedAll = bluetoothManager.connectedAudioDeviceInfos()
        if connectedAll.isEmpty {
            menu.addItem(disabled("No connected BT audio devices"))
        } else {
            menu.addItem(disabled("Connected:"))
            for device in connectedAll {
                let monitored = settings.isMonitored(address: device.address)
                let suffix = monitored ? "" : "  (not monitored)"
                menu.addItem(disabled("   • \(device.name)\(suffix)"))
            }
        }

        menu.addItem(.separator())

        let cancelItem = NSMenuItem(title: "Cancel timer (snooze)", action: #selector(snooze), keyEquivalent: "")
        cancelItem.target = self
        cancelItem.isEnabled = idleController.idleStartedAt != nil || idleController.inGracePeriod
        menu.addItem(cancelItem)

        let disconnectItem = NSMenuItem(title: "Disconnect now", action: #selector(disconnectNow), keyEquivalent: "d")
        disconnectItem.target = self
        disconnectItem.isEnabled = !connectedAll.isEmpty
        menu.addItem(disconnectItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let logsItem = NSMenuItem(title: "Open Log File", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func snooze() {
        idleController.cancelPendingDisconnect()
    }

    @objc private func disconnectNow() {
        idleController.forceDisconnectNow()
    }

    @objc private func showPreferences() {
        if let wc = settingsWindowController, wc.window != nil {
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let wc = SettingsWindowController(
            settings: settings,
            bluetoothManager: bluetoothManager,
            idleController: idleController
        )
        settingsWindowController = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(AppLogger.shared.logFileURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
