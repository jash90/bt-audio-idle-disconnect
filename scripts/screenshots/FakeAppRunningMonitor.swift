import Foundation

// Screenshot harness only — stands in for AppRunningMonitor.swift so the whitelist check
// and the "Add running app…" picker don't depend on (or reveal) what runs on this machine.

final class AppRunningMonitor {
    func runningBundleIDs() -> Set<String> { [] }

    func isAnyRunning(bundleIds: [String]) -> Bool { false }

    func allRunningApps() -> [(bundleId: String, name: String)] {
        [
            ("com.apple.Safari", "Safari"),
            ("com.apple.Music", "Music"),
            ("com.apple.FaceTime", "FaceTime"),
            ("com.spotify.client", "Spotify"),
            ("us.zoom.xos", "zoom.us"),
            ("com.microsoft.teams2", "Microsoft Teams"),
        ]
    }
}
