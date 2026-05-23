import Foundation
import UserNotifications

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    var onCancelTapped: (() -> Void)?

    private let center = UNUserNotificationCenter.current()
    private let categoryId = "BTAID.PRE_DISCONNECT"
    private let cancelActionId = "BTAID.CANCEL_DISCONNECT"
    private let notificationId = "btaid.preDisconnect"

    private override init() {
        super.init()
    }

    func bootstrap() {
        center.delegate = self

        let cancelAction = UNNotificationAction(
            identifier: cancelActionId,
            title: "Cancel",
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

    func sendPreDisconnect(deviceNames: [String], graceSeconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Disconnecting Bluetooth audio"
        let joined = deviceNames.joined(separator: ", ")
        let prefix = deviceNames.isEmpty ? "Devices" : joined
        content.body = "\(prefix) will be disconnected in \(Int(graceSeconds))s. Tap Cancel to keep connected."
        content.sound = .default
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
        if response.actionIdentifier == cancelActionId {
            AppLogger.info("User tapped Cancel in pre-disconnect notification")
            DispatchQueue.main.async { [weak self] in
                self?.onCancelTapped?()
            }
        }
        completionHandler()
    }
}
