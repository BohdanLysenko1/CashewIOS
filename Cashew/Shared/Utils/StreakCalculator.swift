import Foundation

/// Single source of truth for routine streak calculations.
enum StreakCalculator {

    /// Number of days to look back when computing streaks.
    private static let lookbackDays = 90

    /// Current active streak. Today is allowed to be incomplete (grace period).
    static func currentStreak(for routine: DailyRoutine, tasks: [DailyTask]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let routineTasks = tasks.filter { $0.routineId == routine.id }

        var streak = 0
        for dayOffset in 0..<lookbackDays {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            guard routine.shouldRunOn(date: date) else { continue }

            let completed = routineTasks.contains {
                calendar.isDate($0.date, inSameDayAs: date) && $0.isCompleted
            }

            if completed {
                streak += 1
            } else if dayOffset == 0 {
                continue // Today not done yet — still OK
            } else {
                break
            }
        }
        return streak
    }

    /// Returns both current streak and all-time best streak.
    static func streaks(for routine: DailyRoutine, tasks: [DailyTask]) -> (current: Int, best: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let routineTasks = tasks.filter { $0.routineId == routine.id }

        var current = 0
        var best = 0
        var temp = 0
        var currentLocked = false

        for dayOffset in 0..<lookbackDays {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            guard routine.shouldRunOn(date: date) else { continue }

            let completed = routineTasks.contains {
                calendar.isDate($0.date, inSameDayAs: date) && $0.isCompleted
            }

            if completed {
                temp += 1
                best = max(best, temp)
                if !currentLocked {
                    current = temp
                }
            } else if dayOffset == 0 {
                currentLocked = true // today is not done; current streak is locked at 0 for now
                continue
            } else {
                currentLocked = true
                temp = 0
                // Once current streak is established, stop scanning for best streak
                if current != 0 { break }
            }
        }
        return (current, best)
    }
}
