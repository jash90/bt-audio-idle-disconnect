import Combine
import Foundation

struct DeviceSettings: Codable, Equatable {
    var address: String
    var name: String
    var enabled: Bool
    var customTimeoutSeconds: TimeInterval?
}

struct AppRule: Codable, Equatable, Identifiable {
    var id: String { bundleId }
    var bundleId: String
    var displayName: String
}

struct GlobalSettings: Codable, Equatable {
    var globalTimeoutSeconds: TimeInterval = 600
    var preDisconnectGraceSeconds: TimeInterval = 30
    var snoozeOnCancelSeconds: TimeInterval = 300
    var whitelistApps: [AppRule] = []
    var devices: [DeviceSettings] = []
    var notificationsEnabled: Bool = true
    var notificationSoundEnabled: Bool = false
    var playbackConfirmSeconds: TimeInterval = 6
    var reconnectCooldownSeconds: TimeInterval = 60
    var pauseOnSleep: Bool = true
    var disconnectOnSleep: Bool = false
    var autoCheckForUpdates: Bool = true
    var lastUpdateCheck: Date? = nil
    var lastNotifiedUpdateVersion: String? = nil
}

extension GlobalSettings {
    /// Synthesized decoding ignores property defaults and throws on a missing key, and
    /// `SettingsStore` swallows that with `try?` — so one added field would silently reset
    /// every stored device and timeout. Declared in an extension to keep `GlobalSettings()`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        globalTimeoutSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .globalTimeoutSeconds) ?? globalTimeoutSeconds
        preDisconnectGraceSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .preDisconnectGraceSeconds) ?? preDisconnectGraceSeconds
        snoozeOnCancelSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .snoozeOnCancelSeconds) ?? snoozeOnCancelSeconds
        whitelistApps = try c.decodeIfPresent([AppRule].self, forKey: .whitelistApps) ?? whitelistApps
        devices = try c.decodeIfPresent([DeviceSettings].self, forKey: .devices) ?? devices
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? notificationsEnabled
        notificationSoundEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationSoundEnabled) ?? notificationSoundEnabled
        playbackConfirmSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .playbackConfirmSeconds) ?? playbackConfirmSeconds
        reconnectCooldownSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .reconnectCooldownSeconds) ?? reconnectCooldownSeconds
        pauseOnSleep = try c.decodeIfPresent(Bool.self, forKey: .pauseOnSleep) ?? pauseOnSleep
        disconnectOnSleep = try c.decodeIfPresent(Bool.self, forKey: .disconnectOnSleep) ?? disconnectOnSleep
        autoCheckForUpdates = try c.decodeIfPresent(Bool.self, forKey: .autoCheckForUpdates) ?? autoCheckForUpdates
        lastUpdateCheck = try c.decodeIfPresent(Date.self, forKey: .lastUpdateCheck)
        lastNotifiedUpdateVersion = try c.decodeIfPresent(String.self, forKey: .lastNotifiedUpdateVersion)
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var settings: GlobalSettings {
        didSet { scheduleSave() }
    }

    private let url: URL
    private let queue = DispatchQueue(label: "btaid.settings")
    private var saveWorkItem: DispatchWorkItem?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BTAudioIdleDisconnect", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.url = appSupport.appendingPathComponent("settings.json")

        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(GlobalSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = GlobalSettings()
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = settings
        let item = DispatchWorkItem { [url] in
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
        saveWorkItem = item
        queue.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    func deviceSettings(for address: String) -> DeviceSettings? {
        settings.devices.first { $0.address == address }
    }

    func upsertDevice(_ device: DeviceSettings) {
        if let idx = settings.devices.firstIndex(where: { $0.address == device.address }) {
            if settings.devices[idx] != device {
                settings.devices[idx] = device
            }
        } else {
            settings.devices.append(device)
        }
    }

    func setDeviceEnabled(address: String, enabled: Bool) {
        guard let idx = settings.devices.firstIndex(where: { $0.address == address }) else { return }
        settings.devices[idx].enabled = enabled
    }

    func setDeviceTimeout(address: String, timeout: TimeInterval?) {
        guard let idx = settings.devices.firstIndex(where: { $0.address == address }) else { return }
        settings.devices[idx].customTimeoutSeconds = timeout
    }

    func effectiveTimeout(forAddress address: String) -> TimeInterval {
        if let custom = deviceSettings(for: address)?.customTimeoutSeconds {
            return custom
        }
        return settings.globalTimeoutSeconds
    }

    func isMonitored(address: String) -> Bool {
        deviceSettings(for: address)?.enabled ?? true
    }
}
