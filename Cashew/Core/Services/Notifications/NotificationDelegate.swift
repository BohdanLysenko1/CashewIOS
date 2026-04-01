import UserNotifications
import Foundation

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

    /// Called when the user taps a notification or performs a notification action.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier

        // Handle interactive actions
        switch actionId {
        case NotificationAction.markComplete:
            if let taskIdString = userInfo["taskId"] as? String,
               let taskId = UUID(uuidString: taskIdString) {
                NotificationCenter.default.post(
                    name: .didMarkTaskCompleteFromNotification,
                    object: nil,
                    userInfo: ["taskId": taskId]
                )
            }
            completionHandler()
            return

        case NotificationAction.snooze15:
            if let eventIdString = userInfo["eventId"] as? String,
               let eventId = UUID(uuidString: eventIdString) {
                // Snooze: schedule a follow-up notification in 15 minutes
                let content = UNMutableNotificationContent()
                content.title = response.notification.request.content.title
                content.body = "Snoozed reminder — happening soon!"
                content.sound = .default
                content.categoryIdentifier = response.notification.request.content.categoryIdentifier
                content.userInfo = (userInfo as? [String: Any]) ?? [:]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "snooze_\(eventId.uuidString)_\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: trigger
                )
                center.add(request) { _ in }
            } else if let taskIdString = userInfo["taskId"] as? String,
                      let taskId = UUID(uuidString: taskIdString) {
                let content = UNMutableNotificationContent()
                content.title = response.notification.request.content.title
                content.body = "Snoozed reminder — starting soon!"
                content.sound = .default
                content.categoryIdentifier = response.notification.request.content.categoryIdentifier
                content.userInfo = (userInfo as? [String: Any]) ?? [:]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "snooze_\(taskId.uuidString)_\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: trigger
                )
                center.add(request) { _ in }
            }
            completionHandler()
            return

        case NotificationAction.openPlanner:
            NotificationCenter.default.post(name: .didTapDayPlannerNotification, object: nil)
            completionHandler()
            return

        default:
            break // Default tap action — fall through to navigation
        }

        // Handle tap-to-navigate based on notification type
        let type = userInfo["type"] as? String

        switch type {
        case "event":
            if let eventIdString = userInfo["eventId"] as? String,
               let eventId = UUID(uuidString: eventIdString) {
                NotificationCenter.default.post(
                    name: .didTapEventNotification,
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            }

        case "task", "routine":
            NotificationCenter.default.post(name: .didTapDayPlannerNotification, object: nil)

        case "trip":
            if let tripIdString = userInfo["tripId"] as? String,
               let tripId = UUID(uuidString: tripIdString) {
                NotificationCenter.default.post(
                    name: .didTapTripNotification,
                    object: nil,
                    userInfo: ["tripId": tripId]
                )
            }

        case "briefing", "wrapup":
            NotificationCenter.default.post(name: .didTapDayPlannerNotification, object: nil)

        case "levelup":
            NotificationCenter.default.post(name: .didTapProgressNotification, object: nil)

        default:
            // Legacy notifications without "type" field — try eventId
            if let eventIdString = userInfo["eventId"] as? String,
               let eventId = UUID(uuidString: eventIdString) {
                NotificationCenter.default.post(
                    name: .didTapEventNotification,
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            }
        }

        completionHandler()
    }

    // MARK: - Register Notification Categories

    static func registerCategories() {
        let markComplete = UNNotificationAction(
            identifier: NotificationAction.markComplete,
            title: "Mark Complete",
            options: []
        )

        let snooze15 = UNNotificationAction(
            identifier: NotificationAction.snooze15,
            title: "Snooze 15 min",
            options: []
        )

        let openPlanner = UNNotificationAction(
            identifier: NotificationAction.openPlanner,
            title: "Open Day Planner",
            options: .foreground
        )

        let eventCategory = UNNotificationCategory(
            identifier: NotificationCategory.eventReminder,
            actions: [snooze15],
            intentIdentifiers: []
        )

        let taskCategory = UNNotificationCategory(
            identifier: NotificationCategory.taskReminder,
            actions: [markComplete, snooze15],
            intentIdentifiers: []
        )

        let routineCategory = UNNotificationCategory(
            identifier: NotificationCategory.routineNudge,
            actions: [markComplete],
            intentIdentifiers: []
        )

        let tripCountdownCategory = UNNotificationCategory(
            identifier: NotificationCategory.tripCountdown,
            actions: [],
            intentIdentifiers: []
        )

        let tripPackingCategory = UNNotificationCategory(
            identifier: NotificationCategory.tripPacking,
            actions: [],
            intentIdentifiers: []
        )

        let streakCategory = UNNotificationCategory(
            identifier: NotificationCategory.streakProtection,
            actions: [],
            intentIdentifiers: []
        )

        let briefingCategory = UNNotificationCategory(
            identifier: NotificationCategory.morningBriefing,
            actions: [openPlanner],
            intentIdentifiers: []
        )

        let wrapUpCategory = UNNotificationCategory(
            identifier: NotificationCategory.eveningWrapUp,
            actions: [],
            intentIdentifiers: []
        )

        let levelUpCategory = UNNotificationCategory(
            identifier: NotificationCategory.levelUp,
            actions: [],
            intentIdentifiers: []
        )

        let testCategory = UNNotificationCategory(
            identifier: NotificationCategory.testReminder,
            actions: [],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            eventCategory, taskCategory, routineCategory,
            tripCountdownCategory, tripPackingCategory, streakCategory,
            briefingCategory, wrapUpCategory, levelUpCategory, testCategory
        ])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didTapEventNotification = Notification.Name("didTapEventNotification")
    static let didTapTripNotification = Notification.Name("didTapTripNotification")
    static let didTapDayPlannerNotification = Notification.Name("didTapDayPlannerNotification")
    static let didTapProgressNotification = Notification.Name("didTapProgressNotification")
    static let didMarkTaskCompleteFromNotification = Notification.Name("didMarkTaskCompleteFromNotification")
}
