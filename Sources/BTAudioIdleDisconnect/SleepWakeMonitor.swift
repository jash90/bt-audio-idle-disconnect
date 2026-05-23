import AppKit
import Foundation

final class SleepWakeMonitor {
    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    func start() {
        let center = NSWorkspace.shared.notificationCenter

        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            AppLogger.info("System willSleep")
            self?.onSleep?()
        }

        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            AppLogger.info("System didWake")
            self?.onWake?()
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        if let o = sleepObserver { center.removeObserver(o) }
        if let o = wakeObserver { center.removeObserver(o) }
    }
}
