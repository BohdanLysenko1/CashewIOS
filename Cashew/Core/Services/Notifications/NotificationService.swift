import Foundation
import UserNotifications
import Observation

@Observable
@MainActor
final class NotificationService: NotificationServiceProtocol {

    private let notificationCenter = UNUserNotificationCenter.current()

    private(set) var isAuthorized = false

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            isAuthorized = granted
            return granted
        } catch {
            print("NotificationService: Failed to request authorization - \(error.localizedDescription)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Notifications

    func scheduleNotifications(for event: Event) async {
        if !isAuthorized {
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
        let triggerDate = reminder.triggerDate(for: event.date)

        // Don't schedule notifications for past dates
        guard triggerDate > Date() else { return }

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
