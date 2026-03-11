import SwiftUI

struct DashboardView: View {

    @Environment(AppContainer.self) private var container
    @State private var isLoading = true
    @State private var showAddTask = false
    @State private var showDayPlanner = false
    @State private var showProgress = false
    @State private var error: String?

    private var tripService: TripServiceProtocol { container.tripService }
    private var eventService: EventServiceProtocol { container.eventService }
    private var dayPlannerService: DayPlannerServiceProtocol { container.dayPlannerService }
    private var gamification: GamificationService { container.gamificationService }

    // MARK: - Computed — Day Planner

    private var todaysTasks: [DailyTask] {
        dayPlannerService.allTasks.filter {
            Calendar.current.isDateInToday($0.date)
        }
    }

    private var completedTasksCount: Int {
        todaysTasks.filter(\.isCompleted).count
    }

    // MARK: - Computed — Trips

    private var upcomingTrips: [Trip] {
        tripService.trips
            .filter { $0.computedStatus == .upcoming || $0.computedStatus == .planning || $0.computedStatus == .active }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Computed — Events

    private var upcomingEvents: [Event] {
        let now = Date()
        return eventService.events
            .filter { $0.date >= now }
            .sorted { $0.date < $1.date }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Computed — XP & Streak

    private var xpToday: Int {
        let base = todaysTasks.filter(\.isCompleted).reduce(0) { $0 + XPCalculator.xp(for: $1) }
        let bonus = (!todaysTasks.isEmpty && completedTasksCount == todaysTasks.count) ? XPCalculator.dayCompletionBonus : 0
        return base + bonus
    }

    private var currentStreak: Int {
        dayPlannerService.routines
            .filter(\.isEnabled)
            .map { computeCurrentStreak(for: $0) }
            .max() ?? 0
    }

    // MARK: - Computed — Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Good Night"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: Date())
    }

    private var motivationalSubtitle: String {
        // Check if all tasks done
        if !todaysTasks.isEmpty && completedTasksCount == todaysTasks.count {
            return "All tasks done today — crushing it!"
        }

        // Check streak status
        let enabledRoutines = dayPlannerService.routines.filter(\.isEnabled)
        if !enabledRoutines.isEmpty {
            let topStreak = enabledRoutines.compactMap { routine -> (String, Int)? in
                let streak = computeCurrentStreak(for: routine)
                return streak >= 3 ? (routine.title, streak) : nil
            }.max(by: { $0.1 < $1.1 })

            if let (name, count) = topStreak {
                return "\(count)-day streak on \(name)!"
            }
        }

        // Default to task count
        if todaysTasks.isEmpty {
            return "Ready to plan your day?"
        }
        let remaining = todaysTasks.count - completedTasksCount
        return "\(remaining) task\(remaining == 1 ? "" : "s") remaining today"
    }

    // MARK: - Computed — Smart Alerts

    private var smartAlerts: [SmartAlertType] {
        var alerts: [SmartAlertType] = []
        let now = Date()

        // Overdue tasks: scheduled tasks whose time window has passed
        let overdueTask = todaysTasks
            .filter { task in
                guard !task.isCompleted else { return false }
                if let end = task.endTime { return end < now }
                if let start = task.startTime { return start < now - XPCalculator.overdueGracePeriod }
                return false
            }
            .sorted { ($0.endTime ?? $0.startTime ?? $0.date) < ($1.endTime ?? $1.startTime ?? $1.date) }
            .last
        if let task = overdueTask {
            alerts.append(.taskOverdue(taskTitle: task.title))
        }

        // Event starting soon (within 2 hours, non-all-day)
        if let soonEvent = eventService.events
            .filter({ event in
                guard !event.isAllDay else { return false }
                let minutesUntil = event.date.timeIntervalSince(now) / 60
                return minutesUntil >= 0 && minutesUntil <= 120
            })
            .sorted(by: { $0.date < $1.date })
            .first {
            let minutesUntil = max(0, Int(soonEvent.date.timeIntervalSince(now) / 60))
            alerts.append(.eventStartingSoon(eventName: soonEvent.title, minutesUntil: minutesUntil))
        }

        // Task due today: any incomplete task not already caught by taskOverdue
        // (covers both unscheduled and scheduled-but-not-yet-overdue tasks)
        if let dueTask = todaysTasks.first(where: { task in
            guard !task.isCompleted else { return false }
            if let end = task.endTime, end < now { return false }
            if let start = task.startTime, start < now - 1800 { return false }
            return true
        }) {
            alerts.append(.taskDueToday(taskTitle: dueTask.title, dueTime: dueTask.endTime ?? dueTask.startTime))
        }

        // No tasks today
        if todaysTasks.isEmpty {
            alerts.append(.noTasksToday)
        }

        // Streak at risk: enabled routines that should run today but haven't been completed
        for routine in dayPlannerService.routines where routine.isEnabled {
            let streak = computeCurrentStreak(for: routine)
            if streak >= 3 && routine.shouldRunOn(date: Date()) {
                let todayDone = dayPlannerService.allTasks.contains {
                    $0.routineId == routine.id && Calendar.current.isDateInToday($0.date) && $0.isCompleted
                }
                if !todayDone {
                    alerts.append(.streakAtRisk(routineName: routine.title))
                }
            }
        }

        // Trip-related alerts
        for trip in upcomingTrips {
            guard let days = trip.daysUntilTrip, days >= 0 else { continue }

            // Packing needed
            let unpackedCount = trip.packingItems.filter { !$0.isPacked }.count
            if unpackedCount > 0 && days <= 7 {
                alerts.append(.packingNeeded(tripName: trip.name, itemsLeft: unpackedCount, daysUntil: days))
            }

            // Budget warning
            if let progress = trip.budgetProgress, progress > 0.8 {
                alerts.append(.budgetWarning(tripName: trip.name, percentUsed: Int(progress * 100)))
            }

            // Overdue checklist items
            let today = Calendar.current.startOfDay(for: Date())
            let overdueItems = trip.checklistItems.filter {
                !$0.isCompleted && ($0.dueDate.map { Calendar.current.startOfDay(for: $0) < today } ?? false)
            }
            if !overdueItems.isEmpty {
                alerts.append(.overdueChecklist(tripName: trip.name, overdueCount: overdueItems.count))
            }

            // Low readiness for soon trips
            if days <= 5 {
                let readiness = computeTripReadiness(trip)
                if readiness < 0.5 && (!trip.packingItems.isEmpty || !trip.checklistItems.isEmpty) {
                    alerts.append(.lowReadiness(tripName: trip.name, readinessPercent: Int(readiness * 100), daysUntil: days))
                }
            }
        }

        return alerts
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scrollContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if let newLevel = gamification.pendingLevelUp {
                    ZStack {
                        Color.black.opacity(0.45)
                            .ignoresSafeArea()
                            .onTapGesture { gamification.clearLevelUp() }

                        LevelUpBannerView(
                            level: newLevel,
                            title: GamificationService.levels
                                .first { $0.level == newLevel }?.title ?? "",
                            onDismiss: { gamification.clearLevelUp() }
                        )
                    }
                    .transition(.opacity)
                    .zIndex(99)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: gamification.pendingLevelUp)
            .navigationTitle("My Day")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { id in
                if tripService.trip(by: id) != nil {
                    TripDetailView(tripId: id)
                } else {
                    EventDetailView(eventId: id)
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showAddTask) {
                DailyTaskFormView(
                    service: dayPlannerService,
                    tripService: tripService,
                    eventService: eventService,
                    task: nil,
                    defaultDate: Date()
                )
            }
            .sheet(isPresented: $showProgress) {
                NavigationStack {
                    PlayerProgressView(gamification: gamification)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showProgress = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showDayPlanner) {
                DayPlannerView()
            }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Daily Momentum Header
                dailyMomentumSection

                // 2. Today's Mission
                TodaysMissionView(
                    tasks: todaysTasks,
                    onAddTask: { showAddTask = true }
                )

                // 3. Plan My Day tile
                planMyDayTile

                // 4. 7-Day Completion Trend
                CompletionTrendChart(allTasks: dayPlannerService.allTasks)

                // 5. Routine Streaks
                StreakTrackerSection(
                    routines: dayPlannerService.routines,
                    allTasks: dayPlannerService.allTasks
                )

                // 6. Weekly Review Stats
                WeeklyReviewSection(
                    allTasks: dayPlannerService.allTasks,
                    events: eventService.events,
                    routines: dayPlannerService.routines
                )

                // 7. Trip Readiness
                TripReadinessSection(trips: upcomingTrips)

                // 8. Upcoming Events
                if !upcomingEvents.isEmpty {
                    upcomingEventsSection
                }

                // 9. Smart Alerts
                if !smartAlerts.isEmpty {
                    SmartAlertsSection(alerts: smartAlerts)
                }
            }
            .padding()
        }
    }

    // MARK: - Daily Momentum

    private var dailyMomentumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: label + level badge
            HStack {
                Text("MY DAY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("AccentColor"))
                    .tracking(1.5)

                Spacer()

                // Level badge — tappable
                Button { showProgress = true } label: {
                    HStack(spacing: 6) {
                        Text("⭐️ Lv \(gamification.currentLevel)")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundStyle(.white)
                        Text(gamification.levelTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.85))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            // Greeting + date
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Daily progress
            HStack(spacing: 8) {
                Image(systemName: completedTasksCount == 0
                      ? "circle"
                      : completedTasksCount == todaysTasks.count && !todaysTasks.isEmpty
                        ? "checkmark.circle.fill"
                        : "circle.lefthalf.filled")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(completedTasksCount == todaysTasks.count && !todaysTasks.isEmpty
                                     ? .green : Color("AccentColor"))

                Text("\(completedTasksCount) / \(todaysTasks.count) tasks completed")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // XP + streak pills
            HStack(spacing: 10) {
                Label("\(xpToday) XP Today", systemImage: "star.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.gradient)
                    .clipShape(Capsule())

                Label("\(currentStreak) day\(currentStreak == 1 ? "" : "s") streak", systemImage: "flame.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(currentStreak >= 3
                                ? Color.red.gradient
                                : Color(.systemGray3).gradient)
                    .clipShape(Capsule())
            }

            // XP progress bar
            xpProgressBar
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color("AccentColor").opacity(0.15), Color("AccentColor").opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - XP Progress Bar

    private var xpProgressBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("AccentColor").opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color("AccentColor"), Color("AccentColor").opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * gamification.levelProgress, height: 6)
                        .animation(.spring(response: 0.5), value: gamification.levelProgress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(gamification.totalXP) XP total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if gamification.isMaxLevel {
                    Text("Max Level")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AccentColor"))
                } else {
                    Text("\(gamification.xpToNextLevel) XP to Level \(gamification.currentLevel + 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Plan My Day Tile

    private var planMyDayTile: some View {
        Button {
            showDayPlanner = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.dayPlannerGradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan My Day")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    let remaining = todaysTasks.count - completedTasksCount
                    Text(todaysTasks.isEmpty
                         ? "Set up tasks, routines & schedule"
                         : "\(remaining) task\(remaining == 1 ? "" : "s") remaining · Tap to manage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.cardPadding)
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.1), Color.mint.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Upcoming Events

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.eventGradient)
                Text("Upcoming Events")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            ForEach(upcomingEvents) { event in
                NavigationLink(value: event.id) {
                    EventCard(event: event, style: .compact)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Helpers

    private func computeCurrentStreak(for routine: DailyRoutine) -> Int {
        StreakCalculator.currentStreak(for: routine, tasks: dayPlannerService.allTasks)
    }

    private func computeTripReadiness(_ trip: Trip) -> Double {
        let hasPacking = !trip.packingItems.isEmpty
        let hasChecklist = !trip.checklistItems.isEmpty

        if !hasPacking && !hasChecklist { return 1.0 }
        if !hasPacking { return trip.checklistProgress }
        if !hasChecklist { return trip.packingProgress }
        return (trip.packingProgress + trip.checklistProgress) / 2.0
    }

    // MARK: - Load Data

    private func loadData() async {
        do {
            try await tripService.loadTrips()
            try await eventService.loadEvents()
            try await dayPlannerService.loadData()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    DashboardView()
        .environment(AppContainer())
}
