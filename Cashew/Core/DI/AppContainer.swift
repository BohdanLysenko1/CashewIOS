import Foundation
import Observation

@Observable
@MainActor
final class AppContainer {

    // MARK: - Services

    let authService: AuthServiceProtocol
    let tripService: TripServiceProtocol
    let eventService: EventServiceProtocol
    let dayPlannerService: DayPlannerServiceProtocol
    let notificationService: NotificationServiceProtocol
    let syncService: SyncService
    let gamificationService: GamificationService
    let shareService: ShareService

    // MARK: - Init

    init(
        authService: AuthServiceProtocol? = nil,
        tripRepository: TripRepositoryProtocol? = nil,
        eventRepository: EventRepositoryProtocol? = nil,
        dailyTaskRepository: DailyTaskRepositoryProtocol? = nil,
        dailyRoutineRepository: DailyRoutineRepositoryProtocol? = nil,
        notificationService: NotificationService? = nil,
        syncService: SyncService? = nil
    ) {
        // Auth — real Supabase auth by default
        let auth = authService ?? SupabaseAuthService()
        self.authService = auth

        // Repositories — Supabase-backed by default
        let tripRepo = tripRepository ?? SupabaseTripRepository()
        let eventRepo = eventRepository ?? SupabaseEventRepository()
        let taskRepo = dailyTaskRepository ?? LocalDailyTaskRepository()
        let routineRepo = dailyRoutineRepository ?? LocalDailyRoutineRepository()

        // Notification service
        self.notificationService = notificationService ?? NotificationService()

        // Gamification
        let gam = GamificationService()
        self.gamificationService = gam

        // Services
        self.tripService = TripService(repository: tripRepo)
        self.eventService = EventService(
            repository: eventRepo,
            notificationService: self.notificationService
        )
        self.dayPlannerService = DayPlannerService(
            taskRepository: taskRepo,
            routineRepository: routineRepo,
            gamificationService: gam
        )

        // Sync (still used for CloudKit fallback / local backup)
        self.syncService = syncService ?? SyncService(
            localTripRepository: tripRepo,
            localEventRepository: eventRepo
        )

        // Sharing
        self.shareService = ShareService(authService: auth)
    }

    // MARK: - Factory Methods

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(authService: authService)
    }

    // MARK: - App Lifecycle

    func requestNotificationPermission() async {
        _ = await notificationService.requestAuthorization()
    }
}
