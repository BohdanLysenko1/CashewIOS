import UserNotifications

/// Handles foreground notification presentation and notification tap actions.
/// Must be set as `UNUserNotificationCenter.current().delegate` at app launch.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {
        super.init()
    }

    /// Called when the app receives a notification while in the foreground.
    /// Without this, iOS suppresses the notification banner entirely.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when the user taps a notification. Posts a notification so the app
    /// can navigate to the relevant event.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let eventIdString = userInfo["eventId"] as? String,
           let eventId = UUID(uuidString: eventIdString) {
            NotificationCenter.default.post(
                name: .didTapEventNotification,
                object: nil,
                userInfo: ["eventId": eventId]
            )
        }

        completionHandler()
    }
}

extension Notification.Name {
    static let didTapEventNotification = Notification.Name("didTapEventNotification")
}
