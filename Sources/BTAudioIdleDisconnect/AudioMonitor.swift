import CoreAudio
import Foundation

final class AudioMonitor {
    var onStateChange: ((Bool) -> Void)?

    private var currentDeviceID: AudioDeviceID = 0
    private var isPlaying: Bool = false
    private var hasEmittedInitial: Bool = false

    private var deviceRunningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start() {
        currentDeviceID = fetchDefaultOutputDevice()
        AppLogger.info("AudioMonitor start; default device id=\(currentDeviceID)")
        registerDeviceListener(for: currentDeviceID)
        registerDefaultDeviceListener()
        checkState()
    }

    private func fetchDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0, nil, &size, &deviceID
        )
        return deviceID
    }

    private func registerDeviceListener(for deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &deviceRunningAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.checkState()
        }
    }

    private func registerDefaultDeviceListener() {
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            guard let self = self else { return }
            let newID = self.fetchDefaultOutputDevice()
            if newID != self.currentDeviceID {
                AppLogger.info("Default output device changed: \(self.currentDeviceID) → \(newID)")
                self.currentDeviceID = newID
                self.registerDeviceListener(for: newID)
            }
            self.checkState()
        }
    }

    private func checkState() {
        guard currentDeviceID != 0 else { return }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            currentDeviceID,
            &deviceRunningAddress,
            0, nil, &size, &running
        )
        guard status == noErr else { return }
        let nowPlaying = running != 0
        if nowPlaying != isPlaying || !hasEmittedInitial {
            isPlaying = nowPlaying
            hasEmittedInitial = true
            onStateChange?(isPlaying)
        }
    }
}
