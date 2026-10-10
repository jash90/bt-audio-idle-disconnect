import Foundation
import ServiceManagement

final class LoginItemManager {
    static let shared = LoginItemManager()

    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered: return "not registered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requires approval in System Settings"
        case .notFound: return "not found"
        @unknown default: return "unknown"
        }
    }

    /// Same as `statusDescription`, translated for the UI (the English one goes to the log).
    var localizedStatusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered: return L10n.tr("not registered")
        case .enabled: return L10n.tr("enabled")
        case .requiresApproval: return L10n.tr("requires approval in System Settings")
        case .notFound: return L10n.tr("not found")
        @unknown default: return L10n.tr("unknown")
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return true }
                try SMAppService.mainApp.register()
                AppLogger.info("Login item registered; status=\(statusDescription)")
            } else {
                try SMAppService.mainApp.unregister()
                AppLogger.info("Login item unregistered")
            }
            return true
        } catch {
            AppLogger.error("Login item update failed: \(error)")
            return false
        }
    }
}
