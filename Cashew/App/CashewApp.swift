import SwiftUI
import UserNotifications

@main
struct CashewApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @State private var container = AppContainer()
    private let appearance = AppearanceManager.shared
    @State private var pendingInviteToken: String?
    @State private var pendingNotificationEventId: UUID?
    @State private var pendingNotificationTripId: UUID?
    @State private var showDayPlannerFromNotification = false
    @State private var showProgressFromNotification = false

    private let notificationDelegate = NotificationDelegate.shared

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationDelegate.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .preferredColorScheme(appearance.mode.colorScheme)
                .task {
                    await requestNotificationPermissionIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    appearance.syncWithSystem()
                    Task {
                        await refreshNotificationSchedulesIfAuthorized()
                    }
                }
                // Event notification tap
                .onReceive(NotificationCenter.default.publisher(for: .didTapEventNotification)) { note in
                    guard let eventId = note.userInfo?["eventId"] as? UUID else { return }
                    pendingNotificationEventId = eventId
                }
                // Trip notification tap
                .onReceive(NotificationCenter.default.publisher(for: .didTapTripNotification)) { note in
                    guard let tripId = note.userInfo?["tripId"] as? UUID else { return }
                    pendingNotificationTripId = tripId
                }
                // Day planner notification tap
                .onReceive(NotificationCenter.default.publisher(for: .didTapDayPlannerNotification)) { _ in
                    showDayPlannerFromNotification = true
                }
                // Progress notification tap
                .onReceive(NotificationCenter.default.publisher(for: .didTapProgressNotification)) { _ in
                    showProgressFromNotification = true
                }
                // Mark task complete from notification action
                .onReceive(NotificationCenter.default.publisher(for: .didMarkTaskCompleteFromNotification)) { note in
                    guard let taskId = note.userInfo?["taskId"] as? UUID else { return }
                    Task {
                        if let task = container.dayPlannerService.allTasks.first(where: { $0.id == taskId }),
                           !task.isCompleted {
                            try? await container.dayPlannerService.toggleTaskCompletion(task)
                        }
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                // Invite sheet
                .sheet(isPresented: .init(
                    get: { pendingInviteToken != nil && container.authService.isAuthenticated },
                    set: { if !$0 { pendingInviteToken = nil } }
                )) {
                    if let token = pendingInviteToken {
                        AcceptInviteView(token: token)
                            .environment(container)
                    }
                }
                // Event detail sheet (from notification)
                .sheet(isPresented: .init(
                    get: { pendingNotificationEventId != nil },
                    set: { if !$0 { pendingNotificationEventId = nil } }
                )) {
                    if let eventId = pendingNotificationEventId {
                        NavigationStack {
                            EventDetailView(eventId: eventId)
                                .environment(container)
                        }
                    }
                }
                // Trip detail sheet (from notification)
                .sheet(isPresented: .init(
                    get: { pendingNotificationTripId != nil },
                    set: { if !$0 { pendingNotificationTripId = nil } }
                )) {
                    if let tripId = pendingNotificationTripId {
                        NavigationStack {
                            TripDetailView(tripId: tripId)
                                .environment(container)
                        }
                    }
                }
                // Day planner sheet (from notification)
                .sheet(isPresented: $showDayPlannerFromNotification) {
                    DayPlannerView()
                        .environment(container)
                }
                // Progress sheet (from notification)
                .sheet(isPresented: $showProgressFromNotification) {
                    NavigationStack {
                        PlayerProgressView(gamification: container.gamificationService)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showProgressFromNotification = false }
                                }
                            }
                    }
                }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "cashew" else { return }

        switch url.host {
        case "login-callback":
            // Email confirmation / magic link callback from Supabase
            Task {
                try? await container.authService.handleAuthCallback(url: url)
            }
        case "reset-callback":
            // Password reset callback from Supabase
            Task {
                try? await container.authService.handlePasswordResetCallback(url: url)
            }
        case "join":
            // cashew://join/<token>
            guard let rawToken = url.pathComponents.dropFirst().first else { return }
            let token = rawToken.removingPercentEncoding ?? rawToken
            guard !token.isEmpty else { return }
            pendingInviteToken = token
        default:
            break
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermissionIfNeeded() async {
        let key = UserDefaultsKeys.hasRequestedNotificationPermission

        if !UserDefaults.standard.bool(forKey: key) {
            _ = await container.requestNotificationPermission()
            UserDefaults.standard.set(true, forKey: key)
        }

        await refreshNotificationSchedulesIfAuthorized()
    }

    private func refreshNotificationSchedulesIfAuthorized() async {
        await container.notificationService.checkAuthorizationStatus()
        guard container.notificationService.isAuthorized else { return }
        await container.notificationScheduler.rescheduleAll(
            events: container.eventService.events,
            tasks: container.dayPlannerService.allTasks,
            routines: container.dayPlannerService.routines,
            trips: container.tripService.trips,
            gamificationService: container.gamificationService
        )
    }
}
