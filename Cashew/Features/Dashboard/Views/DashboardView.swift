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
            VStack(alignment: .leading, spacing: AppTheme.Space.md) {
                // 1. Greeting
                greetingHeader

                // 2. Today's Mission
                TodaysMissionView(
                    tasks: todaysTasks,
                    onAddTask: { showAddTask = true }
                )

                // 3. Quick Actions
                quickActionsSection

                // 4. Progress
                progressSection

                // 5. Trip Readiness (only when trips are active)
                if !upcomingTrips.isEmpty {
                    TripReadinessSection(trips: upcomingTrips)
                }

                // 6. Weekly Insights
                weeklyInsightsSection

                // 7. Upcoming Events
                if !upcomingEvents.isEmpty {
                    upcomingEventsSection
                }

                // 8. Smart Alerts
                if !smartAlerts.isEmpty {
                    SmartAlertsSection(alerts: smartAlerts)
                }
            }
            .padding(AppTheme.Space.lg)
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
                .background(AppTheme.gamificationGradient)
                .clipShape(Capsule())
                .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 10) {
            planMyDayCard
            addTaskRow
        }
    }

    private var planMyDayCard: some View {
        Button { showDayPlanner = true } label: {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.25, green: 0.2, blue: 0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Highlight overlay
                LinearGradient(
                    colors: [.white.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .center
                )

                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan My Day")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text({
                            let remaining = todaysTasks.count - completedTasksCount
                            if todaysTasks.isEmpty { return "Start fresh — add your first task" }
                            if remaining == 0 { return "All done — review your day" }
                            return "\(remaining) task\(remaining == 1 ? "" : "s") left to complete"
                        }())
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    }

                    Spacer()

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(10)
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .padding(.horizontal, AppTheme.cardPadding)
                .padding(.vertical, 18)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    private var addTaskRow: some View {
        Button { showAddTask = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.dayPlannerGradient)

                Text("Add Task")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.cardPadding)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(icon: "chart.bar.fill", title: "Progress", gradient: AppTheme.gamificationGradient)

            HStack(spacing: 10) {
                progressStatTile(
                    value: "\(xpToday)",
                    unit: "XP",
                    label: "Today",
                    icon: "star.fill",
                    color: .purple
                )

                progressStatTile(
                    value: "\(currentStreak)",
                    unit: "d",
                    label: "Streak",
                    icon: "flame.fill",
                    color: .purple
                )

                Button { showProgress = true } label: {
                    progressStatTile(
                        value: "Lv \(gamification.currentLevel)",
                        unit: "",
                        label: gamification.levelTitle,
                        icon: "trophy.fill",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)
            }

            xpProgressBar
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private func progressStatTile(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.black)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(AppTheme.statTileBackgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.statTileCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.statTileCornerRadius)
                .stroke(color.opacity(AppTheme.statTileBorderOpacity), lineWidth: 1)
        )
    }

    // MARK: - XP Progress Bar

    private var xpProgressBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            AppProgressBar(progress: gamification.levelProgress, color: .purple)

            HStack {
                Spacer()
                if gamification.isMaxLevel {
                    Text("Max Level")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                } else {
                    Text("\(gamification.xpToNextLevel) XP to Level \(gamification.currentLevel + 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Weekly Insights

    private var weeklyInsightsSection: some View {
        VStack(spacing: 16) {
            CompletionTrendChart(allTasks: dayPlannerService.allTasks)

            WeeklyReviewSection(
                allTasks: dayPlannerService.allTasks,
                events: eventService.events,
                routines: dayPlannerService.routines
            )
        }
    }

    // MARK: - Upcoming Events

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "star.circle.fill", title: "Upcoming Events", gradient: AppTheme.eventGradient)

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
            (tripService as? TripService)?.startRealtimeSync()
            (eventService as? EventService)?.startRealtimeSync()
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
