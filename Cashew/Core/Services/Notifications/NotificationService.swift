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

    // MARK: - Event Notifications (existing)

    func scheduleNotifications(for event: Event) async {
        await checkAuthorizationStatus()

        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
            await checkAuthorizationStatus()
        }

        guard isAuthorized else { return }

        await cancelNotifications(for: event.id)

        for reminder in event.reminders where reminder.isEnabled {
            await scheduleEventNotification(for: event, reminder: reminder)
        }
    }

    func scheduleEventReminder(for event: Event, reminder: Reminder) async {
        guard isAuthorized, reminder.isEnabled else { return }
        await scheduleEventNotification(for: event, reminder: reminder)
    }

    private func scheduleEventNotification(for event: Event, reminder: Reminder) async {
        var triggerDate = reminder.triggerDate(for: event.date)
        let now = Date()

        if triggerDate <= now {
            let secondsLate = now.timeIntervalSince(triggerDate)
            guard secondsLate <= 30 else { return }
            triggerDate = now.addingTimeInterval(2)
        }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = eventNotificationBody(for: event, reminder: reminder)
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.eventReminder
        content.userInfo = [
            "type": "event",
            "eventId": event.id.uuidString,
            "reminderId": reminder.id.uuidString
        ]

        let identifier = "event_\(event.id.uuidString)_reminder_\(reminder.id.uuidString)"
        await scheduleCalendarNotification(identifier: identifier, content: content, date: triggerDate)
    }

    private func eventNotificationBody(for event: Event, reminder: Reminder) -> String {
        var body = "Starting \(reminder.interval.notificationStartText)"
        if !event.location.isEmpty {
            body += " at \(event.location)"
        }
        return body
    }

    func cancelNotifications(for eventId: UUID) async {
        await cancelAll(withPrefix: "event_\(eventId.uuidString)")
    }

    func updateNotifications(for event: Event) async {
        await scheduleNotifications(for: event)
    }

    // MARK: - Task Reminders

    func scheduleTaskReminder(task: DailyTask, leadMinutes: Int) async {
        guard let startTime = task.startTime, !task.isCompleted else { return }

        let triggerDate = startTime.addingTimeInterval(-TimeInterval(leadMinutes * 60))
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = leadMinutes > 0
            ? "Starting in \(leadMinutes) minutes — \(task.categoryDisplayName)"
            : "Starting now — \(task.categoryDisplayName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.taskReminder
        content.userInfo = [
            "type": "task",
            "taskId": task.id.uuidString
        ]

        let identifier = "task_\(task.id.uuidString)"
        await scheduleCalendarNotification(identifier: identifier, content: content, date: triggerDate)
    }

    func cancelTaskReminder(taskId: UUID) async {
        await cancelAll(withPrefix: "task_\(taskId.uuidString)")
    }

    // MARK: - Routine Nudges

    func scheduleRoutineNudge(routine: DailyRoutine, date: Date, streakCount: Int) async {
        guard routine.isEnabled, let startTime = routine.startTime else { return }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        guard let hour = timeComponents.hour, let minute = timeComponents.minute,
              let triggerDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date),
              triggerDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for \(routine.title)"
        content.body = streakCount >= 3
            ? "\(streakCount)-day streak! Keep it going."
            : "Start your day right."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.routineNudge
        content.userInfo = [
            "type": "routine",
            "routineId": routine.id.uuidString
        ]

        let dayKey = Self.dayKeyFormatter.string(from: date)
        let identifier = "routine_\(routine.id.uuidString)_\(dayKey)"
        await scheduleCalendarNotification(identifier: identifier, content: content, date: triggerDate)
    }

    // MARK: - Trip Countdown

    func scheduleTripCountdown(trip: Trip, daysUntil: Int) async {
        let calendar = Calendar.current
        guard let countdownDate = calendar.date(byAdding: .day, value: -daysUntil,
                                                to: calendar.startOfDay(for: trip.startDate)),
              let triggerDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: countdownDate),
              triggerDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = trip.name

        let unpackedCount = trip.packingItems.filter { !$0.isPacked }.count
        let readinessHint = unpackedCount > 0 ? "Still have \(unpackedCount) item\(unpackedCount == 1 ? "" : "s") to pack." : "You're all set!"

        if daysUntil == 1 {
            content.body = "Trip to \(trip.destination) starts tomorrow! \(readinessHint)"
        } else {
            content.body = "\(daysUntil) days until your trip to \(trip.destination)! \(readinessHint)"
        }

        content.sound = .default
        content.categoryIdentifier = NotificationCategory.tripCountdown
        content.userInfo = [
            "type": "trip",
            "tripId": trip.id.uuidString
        ]

        let identifier = "trip_\(trip.id.uuidString)_countdown_\(daysUntil)"
        await scheduleCalendarNotification(identifier: identifier, content: content, date: triggerDate)
    }

    // MARK: - Trip Packing

    func scheduleTripPacking(trip: Trip, unpackedCount: Int) async {
        guard unpackedCount > 0 else { return }

        let calendar = Calendar.current
        guard let packingDate = calendar.date(byAdding: .day, value: -2,
                                              to: calendar.startOfDay(for: trip.startDate)),
              let triggerDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: packingDate),
              triggerDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Packing Reminder"
        content.body = "\(unpackedCount) item\(unpackedCount == 1 ? "" : "s") still to pack for \(trip.name). Trip in 2 days!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.tripPacking
        content.userInfo = [
            "type": "trip",
            "tripId": trip.id.uuidString
        ]

        let identifier = "trip_\(trip.id.uuidString)_packing"
        await scheduleCalendarNotification(identifier: identifier, content: content, date: triggerDate)
    }

    // MARK: - Streak Protection

    func scheduleStreakProtection(routineId: UUID, routineName: String, streakCount: Int, date: Date) async {
        let calendar = Calendar.current
        let hour = NotificationPreferences.streakProtectionHour
        let minute = NotificationPreferences.streakProtectionMinute
        guard let triggerDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date),
              triggerDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Streak at risk!"
        content.body = "You haven't completed \(routineName) today. Don't break your \(streakCount)-day streak!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakProtection
        content.userInfo = [
            "type": "routine",
            "routineId": routineId.uuidString
        ]

        let dayKey = Self.dayKeyFormatter.string(from: date)
        let identifier = "streak_\(routineId.uuidString)_\(dayKey)"
        await scheduleCalendarNotification(identifier: identifier, content: content, date: triggerDate)
    }

    // MARK: - Morning Briefing

    func scheduleMorningBriefing(date: Date, taskCount: Int, eventCount: Int, tripTeaser: String?) async {
        let calendar = Calendar.current
        let hour = NotificationPreferences.morningBriefingHour
        let minute = NotificationPreferences.morningBriefingMinute
        guard let triggerDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date),
              triggerDate > Date()
        else { return }

        let greeting: String
        switch hour {
        case 5..<12:  greeting = "Good morning!"
        case 12..<17: greeting = "Good afternoon!"
        default:      greeting = "Hello!"
        }

        let content = UNMutableNotificationContent()
        content.title = greeting

        var parts: [String] = []
        if taskCount > 0 { parts.append("\(taskCount) task\(taskCount == 1 ? "" : "s")") }
        if eventCount > 0 { parts.append("\(eventCount) event\(eventCount == 1 ? "" : "s")") }

        var body = parts.isEmpty ? "No tasks or events today. Enjoy your day!" : "\(parts.joined(separator: ", ")) today."
        if let tripTeaser, !tripTeaser.isEmpty {
            body += " \(tripTeaser)"
        }
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.morningBriefing
        content.userInfo = ["type": "briefing"]

        let dayKey = Self.dayKeyFormatter.string(from: date)
        let identifier = "briefing_\(dayKey)"
        await scheduleCalendarNotification(identifier: identifier, content: content, date: triggerDate)
    }

    // MARK: - Evening Wrap-up

    func scheduleEveningWrapUp(date: Date, completedTasks: Int, totalTasks: Int, xpEarned: Int, streakMessage: String?) async {
        let calendar = Calendar.current
        let hour = NotificationPreferences.eveningWrapUpHour
        let minute = NotificationPreferences.eveningWrapUpMinute
        guard let triggerDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date),
              triggerDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Daily Wrap-up"

        var body: String
        if totalTasks == 0 {
            body = "No tasks today."
        } else if completedTasks == totalTasks {
            body = "All \(totalTasks) tasks done! \(xpEarned) XP earned."
        } else {
            body = "\(completedTasks)/\(totalTasks) tasks done. \(xpEarned) XP earned."
        }
        if let streakMessage, !streakMessage.isEmpty {
            body += " \(streakMessage)"
        }
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.eveningWrapUp
        content.userInfo = ["type": "wrapup"]

        let dayKey = Self.dayKeyFormatter.string(from: date)
        let identifier = "wrapup_\(dayKey)"
        await scheduleCalendarNotification(identifier: identifier, content: content, date: triggerDate)
    }

    // MARK: - Level Up

    func scheduleLevelUp(level: Int, title: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Level \(level) Unlocked!"
        content.body = "You're now a \(title). Keep crushing it!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.levelUp
        content.userInfo = ["type": "levelup"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "levelup_\(level)", content: content, trigger: trigger)

        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["levelup_\(level)"])

        do {
            try await notificationCenter.add(request)
        } catch {
            print("NotificationService: Failed to schedule level-up notification - \(error.localizedDescription)")
        }
    }

    // MARK: - Test Notification

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
        content.categoryIdentifier = NotificationCategory.testReminder

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

    // MARK: - Cancellation

    func cancelAll(withPrefix prefix: String) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let identifiers = pending
            .filter { $0.identifier.hasPrefix(prefix) }
            .map { $0.identifier }
        if !identifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    private func scheduleCalendarNotification(identifier: String, content: UNMutableNotificationContent, date: Date) async {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        do {
            try await notificationCenter.add(request)
        } catch {
            print("NotificationService: Failed to schedule notification '\(identifier)' - \(error.localizedDescription)")
        }
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Debugging

    func getPendingNotifications() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }
}

// MARK: - Notification Categories

enum NotificationCategory {
    static let eventReminder    = "EVENT_REMINDER"
    static let taskReminder     = "TASK_REMINDER"
    static let routineNudge     = "ROUTINE_NUDGE"
    static let tripCountdown    = "TRIP_COUNTDOWN"
    static let tripPacking      = "TRIP_PACKING"
    static let streakProtection = "STREAK_PROTECTION"
    static let morningBriefing  = "MORNING_BRIEFING"
    static let eveningWrapUp    = "EVENING_WRAPUP"
    static let levelUp          = "LEVEL_UP"
    static let testReminder     = "TEST_REMINDER"
}

// MARK: - Notification Actions

enum NotificationAction {
    static let markComplete = "MARK_COMPLETE"
    static let snooze15     = "SNOOZE_15"
    static let openPlanner  = "OPEN_PLANNER"
}
