import SwiftUI

struct DashboardView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @State private var isLoading = true
    @State private var showAddTask = false
    @State private var showDayPlanner = false
    @State private var showProgress = false
    @State private var showProfile = false
    @State private var showCreationWizard = false
    @State private var navigationPath = NavigationPath()
    @State private var pendingCreationResult: CreationResult?
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

    private var dashboardDisplayName: String {
        let name = container.authService.currentUser?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Bodo" : name
    }

    private var dashboardFirstName: String {
        dashboardDisplayName.split(separator: " ").first.map(String.init) ?? dashboardDisplayName
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
        NavigationStack(path: $navigationPath) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scrollContent
                }
            }
            .background(AppTheme.background)
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
            .fullScreenCover(isPresented: $showAddTask) {
                TaskCreationWizardView(
                    service: dayPlannerService,
                    tripService: tripService,
                    eventService: eventService,
                    defaultDate: Date(),
                    onCreated: { _ in showDayPlanner = true },
                    onDismiss: { showAddTask = false }
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environment(container)
            }
            .fullScreenCover(isPresented: $showCreationWizard) {
                TripEventCreationWizardView { created in
                    pendingCreationResult = created
                }
            }
            .onChange(of: showCreationWizard) { _, isShowing in
                guard !isShowing, let created = pendingCreationResult else { return }
                switch created {
                case .trip(let id), .event(let id):
                    navigationPath.append(id)
                case .task:
                    showDayPlanner = true
                }
                pendingCreationResult = nil
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

                // 9. Error banner
                if let error {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.negative)
                        Text(error)
                            .font(AppTheme.TextStyle.secondary)
                            .foregroundStyle(AppTheme.negative)
                        Spacer(minLength: 0)
                    }
                    .padding(AppTheme.Space.md)
                    .background(AppTheme.negativeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(AppTheme.Space.lg)
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                showProfile = true
            } label: {
                UserAvatarView(
                    displayName: dashboardDisplayName,
                    avatarPath: container.authService.currentUser?.avatarPath,
                    size: 52,
                    tint: AppTheme.primary
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(greeting), \(dashboardFirstName)")
                    .font(AppTheme.TextStyle.title)
                    .foregroundStyle(AppTheme.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text(formattedDate)
                    .font(AppTheme.TextStyle.secondary)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

        }
        .padding(.vertical, 2)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 10) {
            planMyDayCard
            createCreationRow
        }
    }

    private var planMyDayCard: some View {
        GradientActionCard(
            title: "Plan My Day",
            subtitle: planMyDaySubtitle,
            icon: "calendar.badge.clock",
            gradient: AppTheme.dayPlannerGradient,
            glowColor: AppTheme.primary
        ) {
            showDayPlanner = true
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            onboardingCoordinator.registerFrame(
                id: "anchor_dashboard_planmyday",
                frame: frame
            )
        }
    }

    private var planMyDaySubtitle: String {
        let remaining = todaysTasks.count - completedTasksCount
        if todaysTasks.isEmpty { return "Start fresh — add your first task" }
        if remaining == 0 { return "All done — review your day" }
        return "\(remaining) task\(remaining == 1 ? "" : "s") left to complete"
    }

    private var addTaskRow: some View {
        Button { showAddTask = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.dayPlannerGradient)

                Text("Add Task")
                    .font(AppTheme.TextStyle.bodyBold)
                    .foregroundStyle(AppTheme.onSurface)

                Spacer()
            }
            .padding(.horizontal, AppTheme.cardPadding)
            .padding(.vertical, 14)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var createCreationRow: some View {
        GradientActionCard(
            title: "Create",
            subtitle: "Trip, event, or task",
            icon: "globe.americas.fill",
            gradient: AppTheme.tripGradient,
            glowColor: AppTheme.secondary
        ) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showCreationWizard = true
        }
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
                    color: AppTheme.tertiary
                )

                progressStatTile(
                    value: "\(currentStreak)",
                    unit: "d",
                    label: "Streak",
                    icon: "flame.fill",
                    color: AppTheme.tertiary
                )

                Button { showProgress = true } label: {
                    progressStatTile(
                        value: "Lv \(gamification.currentLevel)",
                        unit: "",
                        label: gamification.levelTitle,
                        icon: "trophy.fill",
                        color: AppTheme.tertiary
                    )
                }
                .buttonStyle(.plain)
            }

            xpProgressBar
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    private func progressStatTile(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(AppTheme.TextStyle.statMedium)
                    .foregroundStyle(AppTheme.onSurface)
                if !unit.isEmpty {
                    Text(unit)
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }

            Text(label)
                .font(AppTheme.TextStyle.micro)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .lineLimit(1)
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(AppTheme.statTileBackgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.statTileCornerRadius, style: .continuous))
    }

    // MARK: - XP Progress Bar

    private var xpProgressBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            AppProgressBar(progress: gamification.levelProgress, color: AppTheme.tertiary)

            HStack {
                Spacer()
                if gamification.isMaxLevel {
                    Text("Max Level")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.tertiary)
                } else {
                    Text("\(gamification.xpToNextLevel) XP to Level \(gamification.currentLevel + 1)")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
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
        error = nil
        do {
            try await tripService.loadTrips()
            try await eventService.loadEvents()
            try await dayPlannerService.loadData()
        } catch is CancellationError {
            // Task cancellation is expected during view lifecycle changes.
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    DashboardView()
        .environment(AppContainer())
        .environment(OnboardingCoordinator())
}
