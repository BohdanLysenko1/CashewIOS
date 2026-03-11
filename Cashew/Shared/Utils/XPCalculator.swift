import Foundation

/// Single source of truth for XP values across the app.
enum XPCalculator {

    static let dayCompletionBonus = 25

    /// Grace period before a scheduled task is considered overdue (30 minutes).
    static let overdueGracePeriod: TimeInterval = 30 * 60

    private static let longTaskDuration: TimeInterval = 90 * 60   // 90 min
    private static let mediumTaskDuration: TimeInterval = 30 * 60 // 30 min

    /// XP awarded for completing a task, based on its scheduled duration.
    static func xp(for task: DailyTask) -> Int {
        guard let duration = task.duration else { return 10 }
        if duration > longTaskDuration   { return 20 }
        if duration > mediumTaskDuration { return 10 }
        return 5
    }
}
