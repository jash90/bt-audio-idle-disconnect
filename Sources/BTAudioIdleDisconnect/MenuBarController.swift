import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let idleController: IdleController
    private let bluetoothManager: BluetoothManager
    private let settings: SettingsStore

    private let menu = NSMenu()
    private var statusLineItem: NSMenuItem?
    private var updateItem: NSMenuItem?
    private let updater = UpdateChecker.shared
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
        if let updateItem { configureUpdateItem(updateItem) }
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
            return L10n.tr("Status: playing")
        } else if idleController.inGracePeriod {
            let remaining = Int(idleController.remainingSecondsForUI())
            return L10n.tr("Status: disconnecting in %lds", remaining)
        } else if idleController.idleStartedAt != nil {
            let remaining = idleController.remainingSecondsForUI()
            let mins = Int(remaining) / 60
            let secs = Int(remaining) % 60
            return L10n.tr("Status: idle — %ld:%02ld remaining", mins, secs)
        } else {
            return L10n.tr("Status: idle")
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let statusLine = disabled(statusText())
        statusLineItem = statusLine
        menu.addItem(statusLine)

        let connectedAll = bluetoothManager.connectedAudioDeviceInfos()
        if connectedAll.isEmpty {
            menu.addItem(disabled(L10n.tr("No connected BT audio devices")))
        } else {
            menu.addItem(disabled(L10n.tr("Connected:")))
            for device in connectedAll {
                let monitored = settings.isMonitored(address: device.address)
                let suffix = monitored ? "" : "  " + L10n.tr("(not monitored)")
                menu.addItem(disabled("   • \(device.name)\(suffix)"))
            }
        }

        menu.addItem(.separator())

        let cancelItem = NSMenuItem(title: L10n.tr("Cancel timer (snooze)"), action: #selector(snooze), keyEquivalent: "")
        cancelItem.target = self
        cancelItem.isEnabled = idleController.idleStartedAt != nil || idleController.inGracePeriod
        menu.addItem(cancelItem)

        let disconnectItem = NSMenuItem(title: L10n.tr("Disconnect now"), action: #selector(disconnectNow), keyEquivalent: "d")
        disconnectItem.target = self
        disconnectItem.isEnabled = !connectedAll.isEmpty
        menu.addItem(disconnectItem)

        menu.addItem(.separator())

        let update = NSMenuItem(title: "", action: #selector(showUpdates), keyEquivalent: "")
        update.target = self
        configureUpdateItem(update)
        updateItem = update
        menu.addItem(update)

        let prefsItem = NSMenuItem(title: L10n.tr("Preferences…"), action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let logsItem = NSMenuItem(title: L10n.tr("Open Log File"), action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.tr("Quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func configureUpdateItem(_ item: NSMenuItem) {
        switch updater.state {
        case .available(let release):
            item.title = L10n.tr("Install Update %@…", release.displayVersion)
            item.isEnabled = true
        case .checking:
            item.title = L10n.tr("Checking for Updates…")
            item.isEnabled = false
        case .downloading(let progress):
            item.title = L10n.tr("Downloading Update… %ld%%", Int(progress * 100))
            item.isEnabled = false
        case .installing:
            item.title = L10n.tr("Installing Update…")
            item.isEnabled = false
        default:
            item.title = L10n.tr("Check for Updates…")
            item.isEnabled = true
        }
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
        openPreferences(tab: nil)
    }

    /// Opens Preferences on the About tab; starts a check unless an update is already known.
    @objc func showUpdates() {
        openPreferences(tab: .about)
        if case .available = updater.state { return }
        updater.check(userInitiated: true)
    }

    private func openPreferences(tab: SettingsTab?) {
        if let wc = settingsWindowController, wc.window != nil {
            if let tab { wc.selectTab(tab) }
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let wc = SettingsWindowController(
            settings: settings,
            bluetoothManager: bluetoothManager,
            idleController: idleController
        )
        if let tab { wc.selectTab(tab) }
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
