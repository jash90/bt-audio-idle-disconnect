import Foundation
import IOBluetooth

struct BTDeviceInfo: Identifiable, Hashable {
    let address: String
    let name: String
    let isConnected: Bool
    var id: String { address }
}

final class BluetoothManager {
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
