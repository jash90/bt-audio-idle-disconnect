import Foundation
import UserNotifications

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    var onCancelTapped: (() -> Void)?
    var onUpdateNotificationTapped: (() -> Void)?

    private let center = UNUserNotificationCenter.current()
    private let categoryId = "BTAID.PRE_DISCONNECT"
    private let cancelActionId = "BTAID.CANCEL_DISCONNECT"
    private let notificationId = "btaid.preDisconnect"
    private let updateNotificationId = "btaid.update"

    private override init() {
        super.init()
    }

    func bootstrap() {
        center.delegate = self

        let cancelAction = UNNotificationAction(
            identifier: cancelActionId,
            title: L10n.tr("Cancel"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [cancelAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            AppLogger.info("Notification auth granted=\(granted) error=\(error.map { String(describing: $0) } ?? "nil")")
        }
    }

    func sendPreDisconnect(deviceNames: [String], graceSeconds: TimeInterval, withSound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("Disconnecting Bluetooth audio")
        let seconds = Int(graceSeconds)
        content.body = deviceNames.isEmpty
            ? L10n.tr("Devices will be disconnected in %lds. Tap Cancel to keep them connected.", seconds)
            : L10n.tr("%1$@ will be disconnected in %2$lds. Tap Cancel to keep connected.",
                      deviceNames.joined(separator: ", "), seconds)

        // An alert sound opens the default output device, which the idle detector reads as
        // playback — the notification would cancel the very disconnect it announces.
        if withSound {
            content.sound = .default
        }

        content.categoryIdentifier = categoryId

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error = error {
                AppLogger.error("Notification add failed: \(error)")
            }
        }
    }

    /// No sound and no category: it must never carry the pre-disconnect Cancel action.
    func sendUpdateAvailable(version: String) {
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("BT Audio Idle %@ is available", version)
        content.body = L10n.tr("Click to see what's new and install it.")

        let request = UNNotificationRequest(
            identifier: updateNotificationId,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error = error {
                AppLogger.error("Update notification add failed: \(error)")
            }
        }
    }

    func clearPending() {
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == updateNotificationId {
            AppLogger.info("User tapped the update notification")
            DispatchQueue.main.async { [weak self] in
                self?.onUpdateNotificationTapped?()
            }
        } else if response.actionIdentifier == cancelActionId {
            AppLogger.info("User tapped Cancel in pre-disconnect notification")
            DispatchQueue.main.async { [weak self] in
                self?.onCancelTapped?()
            }
        }
        completionHandler()
    }
}
