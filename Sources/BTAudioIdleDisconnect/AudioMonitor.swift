import CoreAudio
import Foundation

/// Watches whether the default output device is actually rendering audio.
///
/// A "started playing" edge is only reported once the device has stayed busy for
/// `playbackConfirmSeconds`. Without that window a sub-second sound — most notably this
/// app's own pre-disconnect notification — reads as playback and cancels the disconnect
/// it was announcing.
final class AudioMonitor {
    var onStateChange: ((Bool) -> Void)?

    private let settings: SettingsStore

    private var currentDeviceID: AudioDeviceID = 0
    private var isPlaying: Bool = false
    private var hasEmittedInitial: Bool = false

    private var confirmTimer: DispatchSourceTimer?
    private var runningSince: Date?

    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var listeningDeviceID: AudioDeviceID = 0

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

    init(settings: SettingsStore = .shared) {
        self.settings = settings
    }

    deinit {
        removeDeviceListener()
    }

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
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0, nil, &size, &deviceID
        )

        if status != noErr {
            AppLogger.error("Reading default output device failed; OSStatus=\(status)")
            return 0
        }

        return deviceID
    }

    private func registerDeviceListener(for deviceID: AudioDeviceID) {
        removeDeviceListener()

        guard deviceID != 0 else { return }

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.checkState()
        }
        let status = AudioObjectAddPropertyListenerBlock(
            deviceID,
            &deviceRunningAddress,
            DispatchQueue.main,
            block
        )

        guard status == noErr else {
            AppLogger.error("Adding is-running listener for device \(deviceID) failed; OSStatus=\(status)")
            return
        }

        deviceListenerBlock = block
        listeningDeviceID = deviceID
    }

    private func removeDeviceListener() {
        guard listeningDeviceID != 0, let block = deviceListenerBlock else { return }

        let status = AudioObjectRemovePropertyListenerBlock(
            listeningDeviceID,
            &deviceRunningAddress,
            DispatchQueue.main,
            block
        )

        // The audio object disappears together with the device it belonged to, so a
        // bad-object status here is the normal outcome of unplugging or disconnecting.
        if status != noErr && status != kAudioHardwareBadObjectError {
            AppLogger.warn("Removing is-running listener for device \(listeningDeviceID) failed; OSStatus=\(status)")
        }

        deviceListenerBlock = nil
        listeningDeviceID = 0
    }

    private func registerDefaultDeviceListener() {
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            guard let self = self else { return }
            let newID = self.fetchDefaultOutputDevice()

            if newID != self.currentDeviceID {
                AppLogger.info("Default output device changed: \(self.currentDeviceID) → \(newID)")
                self.cancelConfirmTimer()
                self.currentDeviceID = newID
                self.registerDeviceListener(for: newID)
            }

            self.checkState()
        }

        if status != noErr {
            AppLogger.error("Adding default-output-device listener failed; OSStatus=\(status)")
        }
    }

    private func readIsRunning() -> Bool? {
        guard currentDeviceID != 0 else { return nil }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            currentDeviceID,
            &deviceRunningAddress,
            0, nil, &size, &running
        )
        guard status == noErr else { return nil }
        return running != 0
    }

    private func checkState() {
        guard let running = readIsRunning() else { return }

        if running {
            deviceStartedRunning()
        } else {
            deviceStoppedRunning()
        }
    }

    private func deviceStartedRunning() {
        guard !isPlaying, confirmTimer == nil else { return }

        runningSince = Date()
        let confirmDelay = max(0, settings.settings.playbackConfirmSeconds)

        guard confirmDelay > 0 else {
            emit(true)
            return
        }

        // A dispatch source with tight leeway, not asyncAfter: the coalescing slack
        // asyncAfter may add is of the same order as the confirmation window itself.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + confirmDelay, leeway: .milliseconds(20))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.cancelConfirmTimer()

            guard self.readIsRunning() == true else { return }

            AppLogger.debug("Playback confirmed after \(Int(confirmDelay))s")
            self.emit(true)
        }
        timer.resume()
        confirmTimer = timer
    }

    private func deviceStoppedRunning() {
        if confirmTimer != nil {
            let blipMs = Int(Date().timeIntervalSince(runningSince ?? Date()) * 1000)
            let window = Int(settings.settings.playbackConfirmSeconds)
            AppLogger.debug("Ignored audio blip (\(blipMs)ms) — stopped before the \(window)s confirm window elapsed")
        }

        cancelConfirmTimer()
        emit(false)
    }

    private func cancelConfirmTimer() {
        confirmTimer?.cancel()
        confirmTimer = nil
        runningSince = nil
    }

    private func emit(_ playing: Bool) {
        guard playing != isPlaying || !hasEmittedInitial else { return }

        isPlaying = playing
        hasEmittedInitial = true
        onStateChange?(playing)
    }
}
