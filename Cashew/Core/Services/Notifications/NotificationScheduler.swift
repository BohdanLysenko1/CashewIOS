import Foundation

/// Central orchestrator for all notifications. Manages the iOS 64-notification
/// budget by prioritizing and scheduling across all notification types.
@MainActor
final class NotificationScheduler {

    private let notificationService: NotificationServiceProtocol

    // Budget caps per category
    private enum Budget {
        static let eventReminders    = 25
        static let taskReminders     = 15
        static let routineNudges     = 8
        static let tripNotifications = 6
        static let streakProtection  = 4
        static let morningBriefing   = 3
        static let eveningWrapUp     = 2
        static let levelUp           = 1
        // Total: 64
    }

    init(notificationService: NotificationServiceProtocol) {
        self.notificationService = notificationService
    }

    // MARK: - Full Reschedule

    /// Cancels all pending notifications and reschedules everything within budget.
    /// Call on app foreground, after data loads, and after bulk changes.
    func rescheduleAll(
        events: [Event],
        tasks: [DailyTask],
        routines: [DailyRoutine],
        trips: [Trip],
        gamificationService: GamificationService
    ) async {
        guard notificationService.isAuthorized else { return }

        notificationService.cancelAllNotifications()

        await scheduleEventReminders(events: events)
        await scheduleTaskReminders(tasks: tasks)
        await scheduleRoutineNudges(routines: routines, allTasks: tasks)
        await scheduleTripNotifications(trips: trips)
        await scheduleStreakProtection(routines: routines, allTasks: tasks)
        await scheduleDailyBriefings(tasks: tasks, events: events, trips: trips, gamificationService: gamificationService)
    }

    // MARK: - Event Reminders

    func rescheduleEventNotifications(events: [Event]) async {
        guard notificationService.isAuthorized else { return }
        // Cancel all event-prefixed notifications
        await notificationService.cancelAll(withPrefix: "event_")
        await scheduleEventReminders(events: events)
    }

    private func scheduleEventReminders(events: [Event]) async {
        let now = Date()

        // Collect all future event reminders, sorted by trigger date
        var candidates: [(event: Event, reminder: Reminder, triggerDate: Date)] = []
        for event in events {
            for reminder in event.reminders where reminder.isEnabled {
                let trigger = reminder.triggerDate(for: event.date)
                if trigger > now {
                    candidates.append((event, reminder, trigger))
                }
            }
        }
        candidates.sort { $0.triggerDate < $1.triggerDate }

        // Schedule individual reminders up to budget (not all reminders per event)
        for candidate in candidates.prefix(Budget.eventReminders) {
            await notificationService.scheduleEventReminder(for: candidate.event, reminder: candidate.reminder)
        }
    }

    // MARK: - Task Reminders

    func rescheduleTaskNotifications(tasks: [DailyTask]) async {
        guard notificationService.isAuthorized else { return }
        await notificationService.cancelAll(withPrefix: "task_")
        await scheduleTaskReminders(tasks: tasks)
    }

    private func scheduleTaskReminders(tasks: [DailyTask]) async {
        guard NotificationPreferences.taskRemindersEnabled else { return }
        let now = Date()
        let lead = NotificationPreferences.taskReminderLeadMinutes

        // Future scheduled, incomplete tasks sorted by startTime
        let candidates = tasks
            .filter { $0.startTime != nil && !$0.isCompleted }
            .filter { ($0.startTime!.addingTimeInterval(-TimeInterval(lead * 60))) > now }
            .sorted { $0.startTime! < $1.startTime! }

        for task in candidates.prefix(Budget.taskReminders) {
            await notificationService.scheduleTaskReminder(task: task, leadMinutes: lead)
        }
    }

    // MARK: - Routine Nudges

    func rescheduleRoutineNotifications(routines: [DailyRoutine], allTasks: [DailyTask]) async {
        guard notificationService.isAuthorized else { return }
        await notificationService.cancelAll(withPrefix: "routine_")
        await scheduleRoutineNudges(routines: routines, allTasks: allTasks)
    }

    private func scheduleRoutineNudges(routines: [DailyRoutine], allTasks: [DailyTask]) async {
        guard NotificationPreferences.routineNudgesEnabled else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var scheduled = 0

        // Schedule for today + next 7 days
        for dayOffset in 0..<8 {
            guard scheduled < Budget.routineNudges else { break }
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            for routine in routines where routine.isEnabled && routine.startTime != nil {
                guard scheduled < Budget.routineNudges else { break }
                guard routine.shouldRunOn(date: date) else { continue }

                // Skip if already completed today
                if dayOffset == 0 {
                    let alreadyDone = allTasks.contains {
                        $0.routineId == routine.id && calendar.isDate($0.date, inSameDayAs: date) && $0.isCompleted
                    }
                    if alreadyDone { continue }
                }

                let streak = StreakCalculator.currentStreak(for: routine, tasks: allTasks)
                await notificationService.scheduleRoutineNudge(routine: routine, date: date, streakCount: streak)
                scheduled += 1
            }
        }
    }

    // MARK: - Trip Notifications

    func rescheduleTripNotifications(trips: [Trip]) async {
        guard notificationService.isAuthorized else { return }
        await notificationService.cancelAll(withPrefix: "trip_")
        await scheduleTripNotifications(trips: trips)
    }

    private func scheduleTripNotifications(trips: [Trip]) async {
        guard NotificationPreferences.tripCountdownEnabled else { return }
        let now = Date()
        var scheduled = 0

        // Future upcoming/planning trips sorted by startDate
        let upcomingTrips = trips
            .filter { $0.startDate > now && ($0.computedStatus == .upcoming || $0.computedStatus == .planning) }
            .sorted { $0.startDate < $1.startDate }

        for trip in upcomingTrips {
            guard scheduled < Budget.tripNotifications else { break }

            if let days = trip.daysUntilTrip {
                // Countdown: 7d, 3d, 1d
                for milestone in [7, 3, 1] where days >= milestone {
                    guard scheduled < Budget.tripNotifications else { break }
                    await notificationService.scheduleTripCountdown(trip: trip, daysUntil: milestone)
                    scheduled += 1
                }

                // Packing reminder at 2 days
                let unpackedCount = trip.packingItems.filter { !$0.isPacked }.count
                if unpackedCount > 0 && days >= 2 && scheduled < Budget.tripNotifications {
                    await notificationService.scheduleTripPacking(trip: trip, unpackedCount: unpackedCount)
                    scheduled += 1
                }
            }
        }
    }

    // MARK: - Streak Protection

    func rescheduleStreakProtection(routines: [DailyRoutine], allTasks: [DailyTask]) async {
        guard notificationService.isAuthorized else { return }
        await notificationService.cancelAll(withPrefix: "streak_")
        await scheduleStreakProtection(routines: routines, allTasks: allTasks)
    }

    private func scheduleStreakProtection(routines: [DailyRoutine], allTasks: [DailyTask]) async {
        guard NotificationPreferences.streakProtectionEnabled else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var scheduled = 0

        for routine in routines where routine.isEnabled {
            guard scheduled < Budget.streakProtection else { break }

            let streak = StreakCalculator.currentStreak(for: routine, tasks: allTasks)
            guard streak >= 3 else { continue }
            guard routine.shouldRunOn(date: today) else { continue }

            // Check if already completed today
            let todayDone = allTasks.contains {
                $0.routineId == routine.id && calendar.isDate($0.date, inSameDayAs: today) && $0.isCompleted
            }
            guard !todayDone else { continue }

            await notificationService.scheduleStreakProtection(
                routineId: routine.id,
                routineName: routine.title,
                streakCount: streak,
                date: today
            )
            scheduled += 1
        }
    }

    // MARK: - Daily Briefings

    func rescheduleDailyBriefings(
        tasks: [DailyTask],
        events: [Event],
        trips: [Trip],
        gamificationService: GamificationService
    ) async {
        guard notificationService.isAuthorized else { return }
        await notificationService.cancelAll(withPrefix: "briefing_")
        await notificationService.cancelAll(withPrefix: "wrapup_")
        await scheduleDailyBriefings(tasks: tasks, events: events, trips: trips, gamificationService: gamificationService)
    }

    private func scheduleDailyBriefings(
        tasks: [DailyTask],
        events: [Event],
        trips: [Trip],
        gamificationService: GamificationService
    ) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Morning briefings for today + next 2 days
        if NotificationPreferences.morningBriefingEnabled {
            for dayOffset in 0..<Budget.morningBriefing {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

                let dayTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: date) }
                let dayEvents = events.filter { calendar.isDate($0.date, inSameDayAs: date) }

                // Trip teaser: nearest upcoming trip
                let tripTeaser: String? = trips
                    .filter { $0.startDate > date && ($0.computedStatus == .upcoming || $0.computedStatus == .planning) }
                    .sorted { $0.startDate < $1.startDate }
                    .first
                    .map { trip in
                        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: trip.startDate)).day ?? 0
                        return days > 0 ? "Trip to \(trip.destination) in \(days) day\(days == 1 ? "" : "s")!" : nil
                    } ?? nil

                await notificationService.scheduleMorningBriefing(
                    date: date,
                    taskCount: dayTasks.count,
                    eventCount: dayEvents.count,
                    tripTeaser: tripTeaser
                )
            }
        }

        // Evening wrap-ups for today + tomorrow
        if NotificationPreferences.eveningWrapUpEnabled {
            for dayOffset in 0..<Budget.eveningWrapUp {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

                let dayTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: date) }
                let completed = dayTasks.filter(\.isCompleted).count

                // Estimate XP (simplified — actual XP depends on streak multiplier)
                let xp = dayTasks.filter(\.isCompleted).reduce(0) { $0 + XPCalculator.xp(for: $1) }

                let streakMsg: String? = {
                    guard dayOffset == 0 else { return nil }
                    if completed == dayTasks.count && !dayTasks.isEmpty {
                        return "All caught up!"
                    }
                    return nil
                }()

                await notificationService.scheduleEveningWrapUp(
                    date: date,
                    completedTasks: completed,
                    totalTasks: dayTasks.count,
                    xpEarned: xp,
                    streakMessage: streakMsg
                )
            }
        }
    }

    // MARK: - Level Up

    func scheduleLevelUpIfNeeded(gamificationService: GamificationService) async {
        guard NotificationPreferences.levelUpEnabled else { return }
        guard notificationService.isAuthorized else { return }
        guard let newLevel = gamificationService.pendingLevelUp else { return }

        let title = GamificationService.levels.first { $0.level == newLevel }?.title ?? "Champion"
        await notificationService.scheduleLevelUp(level: newLevel, title: title)
    }
}
