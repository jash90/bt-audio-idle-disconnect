import Foundation
import IOBluetooth

struct BTDeviceInfo: Identifiable, Hashable {
    let address: String
    let name: String
    let isConnected: Bool
    var id: String { address }
}

final class BluetoothManager: NSObject {
    /// Fires when a paired audio device connects or drops, so the idle timer can be armed
    /// for headphones that connect while nothing is playing — an audio state change alone
    /// never happens in that case.
    var onConnectionChange: (() -> Void)?

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]

    func startConnectionNotifications() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        pairedAudioDevices().filter { $0.isConnected() }.forEach(observeDisconnect)
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard Self.isAudio(device) else { return }

        AppLogger.info("BT audio device connected: \(device.name ?? device.addressString ?? "unknown")")
        observeDisconnect(device)
        onConnectionChange?()
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()

        guard let address = device.addressString,
              disconnectNotifications.removeValue(forKey: address) != nil else { return }

        AppLogger.info("BT audio device disconnected: \(device.name ?? address)")
        onConnectionChange?()
    }

    /// `register(forConnectNotifications:)` also fires for devices that are already
    /// connected, so the same device can arrive twice — keep one observer per address.
    private func observeDisconnect(_ device: IOBluetoothDevice) {
        guard let address = device.addressString, disconnectNotifications[address] == nil else { return }

        disconnectNotifications[address] = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))
        )
    }

    func pairedDevices() -> [IOBluetoothDevice] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    }

    func pairedAudioDevices() -> [IOBluetoothDevice] {
        pairedDevices().filter { Self.isAudio($0) }
    }

    func pairedAudioDeviceInfos() -> [BTDeviceInfo] {
        pairedAudioDevices().compactMap { d in
            guard let address = d.addressString else { return nil }
            return BTDeviceInfo(
                address: address,
                name: d.name ?? address,
                isConnected: d.isConnected()
            )
        }
    }

    func connectedAudioDeviceInfos() -> [BTDeviceInfo] {
        pairedAudioDeviceInfos().filter { $0.isConnected }
    }

    @discardableResult
    func disconnect(address: String) -> Bool {
        guard let device = pairedDevices().first(where: { $0.addressString == address }) else {
            AppLogger.warn("Disconnect requested for \(address) — device not found")
            return false
        }
        guard device.isConnected() else {
            AppLogger.debug("Device \(address) already disconnected")
            return false
        }
        let result = device.closeConnection()
        AppLogger.info("Disconnect \(device.name ?? address) (\(address)) → IOReturn=\(result)")
        return result == kIOReturnSuccess
    }

    /// Bluetooth Major Device Class 0x04 = Audio/Video.
    static func isAudio(_ device: IOBluetoothDevice) -> Bool {
        let cod = device.classOfDevice
        let major = (cod >> 8) & 0x1F
        return major == 0x04
    }
}
