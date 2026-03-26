import Foundation
import UserNotifications
import Observation

@Observable
@MainActor
final class NotificationService: NotificationServiceProtocol {

    private let notificationCenter = UNUserNotificationCenter.current()

    private(set) var isAuthorized = false
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var alertSetting: UNNotificationSetting = .notSupported

    var canRequestAuthorization: Bool {
        authorizationStatus == .notDetermined
    }

    var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .authorized:
            return alertSetting == .enabled ? "Authorized" : "Authorized (Alerts Off)"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await checkAuthorizationStatus()
            return granted || isAuthorized
        } catch {
            print("NotificationService: Failed to request authorization - \(error.localizedDescription)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        alertSetting = settings.alertSetting
        isAuthorized = settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional ||
            settings.authorizationStatus == .ephemeral
    }

    // MARK: - Schedule Notifications

    func scheduleNotifications(for event: Event) async {
        await checkAuthorizationStatus()

        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
            await checkAuthorizationStatus()
        }

        guard isAuthorized else { return }

        // Cancel any existing notifications for this event first
        await cancelNotifications(for: event.id)

        // Schedule notifications for each enabled reminder
        for reminder in event.reminders where reminder.isEnabled {
            await scheduleNotification(for: event, reminder: reminder)
        }
    }

    private func scheduleNotification(for event: Event, reminder: Reminder) async {
        var triggerDate = reminder.triggerDate(for: event.date)
        let now = Date()

        // Skip reminders that are substantially in the past, but allow very recent
        // "at time" reminders to fire immediately.
        if triggerDate <= now {
            let secondsLate = now.timeIntervalSince(triggerDate)
            guard secondsLate <= 30 else { return }
            triggerDate = now.addingTimeInterval(2)
        }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = notificationBody(for: event, reminder: reminder)
        content.sound = .default
        content.categoryIdentifier = "EVENT_REMINDER"

        // Add event info to userInfo for potential deep linking
        content.userInfo = [
            "eventId": event.id.uuidString,
            "reminderId": reminder.id.uuidString
        ]

        // Create trigger based on the reminder's trigger date
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        // Create unique identifier for this notification
        let identifier = notificationIdentifier(eventId: event.id, reminderId: reminder.id)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("NotificationService: Failed to schedule notification - \(error.localizedDescription)")
        }
    }

    private func notificationBody(for event: Event, reminder: Reminder) -> String {
        var body = reminder.interval == .atTime
            ? "Starting now"
            : "Starting \(reminder.interval.displayName.lowercased())"

        if !event.location.isEmpty {
            body += " at \(event.location)"
        }

        return body
    }

    // MARK: - Cancel Notifications

    func cancelNotifications(for eventId: UUID) async {
        let pending = await notificationCenter.pendingNotificationRequests()

        let identifiersToRemove = pending
            .filter { $0.identifier.hasPrefix("event_\(eventId.uuidString)") }
            .map { $0.identifier }

        if !identifiersToRemove.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }

    // MARK: - Update Notifications

    func updateNotifications(for event: Event) async {
        // Simply cancel and reschedule
        await scheduleNotifications(for: event)
    }

    func scheduleTestNotification(after seconds: TimeInterval = 5) async -> Bool {
        await checkAuthorizationStatus()

        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
            await checkAuthorizationStatus()
        }

        guard isAuthorized else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Cashew Test Reminder"
        content.body = "Notifications are working."
        content.sound = .default
        content.categoryIdentifier = "TEST_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds),
            repeats: false
        )

        let identifier = "test_notification"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            print("NotificationService: Failed to schedule test notification - \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Helpers

    private func notificationIdentifier(eventId: UUID, reminderId: UUID) -> String {
        "event_\(eventId.uuidString)_reminder_\(reminderId.uuidString)"
    }

    // MARK: - Debugging

    func getPendingNotifications() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
}
