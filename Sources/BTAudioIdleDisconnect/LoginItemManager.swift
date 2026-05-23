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
