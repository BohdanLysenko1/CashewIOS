import SwiftUI
import UserNotifications

@main
struct CashewApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @State private var container = AppContainer()
    @State private var pendingInviteToken: String?
    @State private var pendingNotificationEventId: UUID?

    private let notificationDelegate = NotificationDelegate.shared

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .task {
                    await requestNotificationPermissionIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await refreshNotificationSchedulesIfAuthorized()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didTapEventNotification)) { note in
                    guard let eventId = note.userInfo?["eventId"] as? UUID else { return }
                    pendingNotificationEventId = eventId
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .sheet(isPresented: .init(
                    get: { pendingInviteToken != nil && container.authService.isAuthenticated },
                    set: { if !$0 { pendingInviteToken = nil } }
                )) {
                    if let token = pendingInviteToken {
                        AcceptInviteView(token: token)
                            .environment(container)
                    }
                }
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
        await container.eventService.refreshNotificationSchedules()
    }
}
