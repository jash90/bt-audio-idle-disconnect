// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BTAudioIdleDisconnect",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BTAudioIdleDisconnect",
            path: "Sources/BTAudioIdleDisconnect",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
