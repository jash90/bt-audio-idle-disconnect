import Foundation

final class IdleController {
    private let bluetoothManager: BluetoothManager
    private let appRunningMonitor: AppRunningMonitor
    private let settings: SettingsStore
    private let notifications: NotificationManager

    private var idleTimer: DispatchSourceTimer?
    private var graceTimer: DispatchSourceTimer?

    private(set) var isAudioPlaying: Bool = false
    private(set) var idleStartedAt: Date?
    private(set) var currentIdleDuration: TimeInterval = 0
    private(set) var graceStartedAt: Date?
    private(set) var inGracePeriod: Bool = false
    private var lastDisconnectAt: Date?

    var onStateChange: (() -> Void)?

    init(
        bluetoothManager: BluetoothManager,
        appRunningMonitor: AppRunningMonitor,
        settings: SettingsStore,
        notifications: NotificationManager
    ) {
        self.bluetoothManager = bluetoothManager
        self.appRunningMonitor = appRunningMonitor
        self.settings = settings
        self.notifications = notifications

        notifications.onCancelTapped = { [weak self] in
            self?.cancelPendingDisconnect()
        }
    }

    func audioPlaybackChanged(isPlaying: Bool) {
        isAudioPlaying = isPlaying
        if isPlaying {
            stopAllTimers()
            idleStartedAt = nil
            graceStartedAt = nil
            notifications.clearPending()
            AppLogger.info("Audio resumed — idle timer cleared")
        } else {
            startIdleTimerIfNeeded()
        }
        onStateChange?()
    }

    func systemWillSleep() {
        if settings.settings.disconnectOnSleep {
            AppLogger.info("System sleeping — disconnecting all monitored devices")
            disconnectMonitoredDevices()
        } else if settings.settings.pauseOnSleep {
            AppLogger.info("System sleeping — pausing timers")
            stopAllTimers()
            idleStartedAt = nil
            graceStartedAt = nil
            notifications.clearPending()
        }
        onStateChange?()
    }

    func systemDidWake() {
        if !isAudioPlaying {
            startIdleTimerIfNeeded()
        }
        onStateChange?()
    }

    func cancelPendingDisconnect() {
        let wasPending = idleTimer != nil || graceTimer != nil
        stopAllTimers()
        notifications.clearPending()
        if wasPending && !bluetoothManager.connectedAudioDeviceInfos().isEmpty {
            let snooze = settings.settings.snoozeOnCancelSeconds
            AppLogger.info("Snoozing for \(Int(snooze))s")
            idleStartedAt = Date()
            currentIdleDuration = snooze
            scheduleIdleFire(after: snooze)
        }
        onStateChange?()
    }

    func forceDisconnectNow() {
        AppLogger.info("Manual disconnect requested")
        stopAllTimers()
        notifications.clearPending()
        idleStartedAt = nil
        graceStartedAt = nil
        disconnectMonitoredDevices()
        onStateChange?()
    }

    func recomputeMonitoredState() {
        if !isAudioPlaying {
            startIdleTimerIfNeeded()
        }
        onStateChange?()
    }

    private func startIdleTimerIfNeeded() {
        stopAllTimers()
        idleStartedAt = nil
        graceStartedAt = nil

        let monitored = monitoredConnectedDevices()
        guard !monitored.isEmpty else {
            AppLogger.debug("No monitored connected devices")
            return
        }

        if isWhitelistedAppRunning() {
            AppLogger.info("Whitelisted app running — timer suppressed")
            return
        }

        let timeouts = monitored.map { settings.effectiveTimeout(forAddress: $0.address) }
        let configured = timeouts.min() ?? settings.settings.globalTimeoutSeconds
        // A device that came back right after we dropped it gets the cooldown as a floor,
        // so an auto-reconnect can't be met with an immediate second disconnect.
        let timeout = max(configured, reconnectCooldownRemaining())

        if timeout > configured {
            AppLogger.info("Reconnect cooldown active — first fire deferred to \(Int(timeout))s")
        }

        idleStartedAt = Date()
        currentIdleDuration = timeout
        let names = monitored.map { $0.name }.joined(separator: ", ")
        AppLogger.info("Idle timer started; firing in \(Int(timeout))s for \(names)")
        scheduleIdleFire(after: timeout)
    }

    private func scheduleIdleFire(after seconds: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + seconds)
        timer.setEventHandler { [weak self] in
            self?.beginGracePeriod()
        }
        timer.resume()
        idleTimer = timer
    }

    private func beginGracePeriod() {
        idleTimer = nil

        if isWhitelistedAppRunning() {
            AppLogger.info("Whitelisted app started during countdown — disconnect aborted")
            startIdleTimerIfNeeded()
            onStateChange?()
            return
        }

        let grace = settings.settings.preDisconnectGraceSeconds
        if grace <= 0 {
            disconnectMonitoredDevices()
            idleStartedAt = nil
            onStateChange?()
            return
        }
        inGracePeriod = true
        graceStartedAt = Date()
        let names = monitoredConnectedDevices().map { $0.name }
        AppLogger.info("Grace period started; disconnect in \(Int(grace))s")
        if settings.settings.notificationsEnabled {
            notifications.sendPreDisconnect(
                deviceNames: names,
                graceSeconds: grace,
                withSound: settings.settings.notificationSoundEnabled
            )
        }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + grace)
        timer.setEventHandler { [weak self] in
            self?.disconnectMonitoredDevices()
            self?.inGracePeriod = false
            self?.idleStartedAt = nil
            self?.graceStartedAt = nil
            self?.onStateChange?()
        }
        timer.resume()
        graceTimer = timer
        onStateChange?()
    }

    private func disconnectMonitoredDevices() {
        notifications.clearPending()
        let monitored = monitoredConnectedDevices()
        if monitored.isEmpty {
            AppLogger.info("Nothing to disconnect")
            return
        }
        var disconnectedAny = false

        for d in monitored {
            disconnectedAny = bluetoothManager.disconnect(address: d.address) || disconnectedAny
        }

        if disconnectedAny {
            lastDisconnectAt = Date()
        }
    }

    private func isWhitelistedAppRunning() -> Bool {
        let bundleIds = settings.settings.whitelistApps.map { $0.bundleId }
        return appRunningMonitor.isAnyRunning(bundleIds: bundleIds)
    }

    private func reconnectCooldownRemaining() -> TimeInterval {
        guard let last = lastDisconnectAt else { return 0 }
        return max(0, settings.settings.reconnectCooldownSeconds - Date().timeIntervalSince(last))
    }

    private func stopAllTimers() {
        idleTimer?.cancel(); idleTimer = nil
        graceTimer?.cancel(); graceTimer = nil
        inGracePeriod = false
    }

    func monitoredConnectedDevices() -> [BTDeviceInfo] {
        bluetoothManager.connectedAudioDeviceInfos().filter {
            settings.isMonitored(address: $0.address)
        }
    }

    func remainingSecondsForUI() -> TimeInterval {
        if inGracePeriod, let g = graceStartedAt {
            let elapsed = Date().timeIntervalSince(g)
            return max(0, settings.settings.preDisconnectGraceSeconds - elapsed)
        }
        if let start = idleStartedAt {
            let elapsed = Date().timeIntervalSince(start)
            return max(0, currentIdleDuration - elapsed)
        }
        return 0
    }
}
