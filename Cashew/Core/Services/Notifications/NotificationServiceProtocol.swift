import Foundation
import UserNotifications

@MainActor
protocol NotificationServiceProtocol: AnyObject {
    var isAuthorized: Bool { get }
    var canRequestAuthorization: Bool { get }
    var authorizationStatusDescription: String { get }

    func requestAuthorization() async -> Bool
    func checkAuthorizationStatus() async

    // Event notifications
    func scheduleNotifications(for event: Event) async
    func scheduleEventReminder(for event: Event, reminder: Reminder) async
    func cancelNotifications(for eventId: UUID) async
    func updateNotifications(for event: Event) async

    // Task reminders
    func scheduleTaskReminder(task: DailyTask, leadMinutes: Int) async
    func cancelTaskReminder(taskId: UUID) async

    // Routine nudges
    func scheduleRoutineNudge(routine: DailyRoutine, date: Date, streakCount: Int) async

    // Trip notifications
    func scheduleTripCountdown(trip: Trip, daysUntil: Int) async
    func scheduleTripPacking(trip: Trip, unpackedCount: Int) async

    // Streak protection
    func scheduleStreakProtection(routineId: UUID, routineName: String, streakCount: Int, date: Date) async

    // Daily briefings
    func scheduleMorningBriefing(date: Date, taskCount: Int, eventCount: Int, tripTeaser: String?) async
    func scheduleEveningWrapUp(date: Date, completedTasks: Int, totalTasks: Int, xpEarned: Int, streakMessage: String?) async

    // Level up
    func scheduleLevelUp(level: Int, title: String) async

    // Cancellation
    func cancelAll(withPrefix prefix: String) async
    func cancelAllNotifications()

    // Test
    func scheduleTestNotification(after seconds: TimeInterval) async -> Bool

    // Debug
    func getPendingNotifications() async -> [UNNotificationRequest]
}
