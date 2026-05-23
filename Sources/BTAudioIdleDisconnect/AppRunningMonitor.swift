import AppKit
import Foundation

final class AppRunningMonitor {
    func runningBundleIDs() -> Set<String> {
        var result = Set<String>()
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier { result.insert(id) }
        }
        return result
    }

    func isAnyRunning(bundleIds: [String]) -> Bool {
        guard !bundleIds.isEmpty else { return false }
        let running = runningBundleIDs()
        return bundleIds.contains(where: { running.contains($0) })
    }

    func allRunningApps() -> [(bundleId: String, name: String)] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier,
                  app.activationPolicy != .prohibited
            else { return nil }
            return (id, app.localizedName ?? id)
        }
    }
}
