import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private let audioMonitor = AudioMonitor()
    private let bluetoothManager = BluetoothManager()
    private let appRunningMonitor = AppRunningMonitor()
    private let sleepWakeMonitor = SleepWakeMonitor()
    private let notifications = NotificationManager.shared

    private var idleController: IdleController!
    private var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.info("App launched")

        notifications.bootstrap()

        idleController = IdleController(
            bluetoothManager: bluetoothManager,
            appRunningMonitor: appRunningMonitor,
            settings: settings,
            notifications: notifications
        )

        menuBar = MenuBarController(
            idleController: idleController,
            bluetoothManager: bluetoothManager,
            settings: settings
        )

        bluetoothManager.onConnectionChange = { [weak self] in
            self?.idleController.recomputeMonitoredState()
        }
        bluetoothManager.startConnectionNotifications()

        audioMonitor.onStateChange = { [weak self] isPlaying in
            self?.idleController.audioPlaybackChanged(isPlaying: isPlaying)
        }
        audioMonitor.start()

        sleepWakeMonitor.onSleep = { [weak self] in self?.idleController.systemWillSleep() }
        sleepWakeMonitor.onWake  = { [weak self] in self?.idleController.systemDidWake() }
        sleepWakeMonitor.start()

        notifications.onUpdateNotificationTapped = { [weak self] in
            self?.menuBar.showUpdates()
        }
        UpdateChecker.shared.startAutomaticChecks()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLogger.info("App terminating")
    }
}
