import Foundation

// Screenshot harness only — stands in for Sources/.../BluetoothManager.swift so the real
// SwiftUI/AppKit UI renders fictional devices instead of the machine's paired hardware.
// Same surface as the real type; nothing here is compiled into the shipped app.

struct BTDeviceInfo: Identifiable, Hashable {
    let address: String
    let name: String
    let isConnected: Bool
    var id: String { address }
}

final class BluetoothManager: NSObject {
    var onConnectionChange: (() -> Void)?

    /// Fictional devices; the addresses are made-up, not real hardware.
    static let demoDevices: [BTDeviceInfo] = [
        BTDeviceInfo(address: "0a-1b-2c-3d-4e-01", name: "Studio Headphones", isConnected: true),
        BTDeviceInfo(address: "0a-1b-2c-3d-4e-02", name: "Kitchen Speaker", isConnected: true),
        BTDeviceInfo(address: "0a-1b-2c-3d-4e-03", name: "Running Earbuds", isConnected: false),
        BTDeviceInfo(address: "0a-1b-2c-3d-4e-04", name: "Office Headset", isConnected: false),
    ]

    func startConnectionNotifications() {}

    func pairedAudioDeviceInfos() -> [BTDeviceInfo] { Self.demoDevices }

    func connectedAudioDeviceInfos() -> [BTDeviceInfo] {
        pairedAudioDeviceInfos().filter { $0.isConnected }
    }

    @discardableResult
    func disconnect(address: String) -> Bool { false }
}
