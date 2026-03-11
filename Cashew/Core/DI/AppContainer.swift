import Foundation
import Observation

@Observable
final class AppContainer {

    // MARK: - Repositories

    private let localTripRepository: TripRepositoryProtocol
    private let localEventRepository: EventRepositoryProtocol
    private let localDailyTaskRepository: DailyTaskRepositoryProtocol
    private let localDailyRoutineRepository: DailyRoutineRepositoryProtocol

    // MARK: - Services

    let authService: AuthServiceProtocol
    let tripService: TripServiceProtocol
    let eventService: EventServiceProtocol
    let dayPlannerService: DayPlannerServiceProtocol
    let notificationService: NotificationServiceProtocol
    let syncService: SyncService
    let gamificationService: GamificationService

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
        // Local repositories (source of truth)
        self.localTripRepository = tripRepository ?? LocalTripRepository()
        self.localEventRepository = eventRepository ?? LocalEventRepository()
        self.localDailyTaskRepository = dailyTaskRepository ?? LocalDailyTaskRepository()
        self.localDailyRoutineRepository = dailyRoutineRepository ?? LocalDailyRoutineRepository()

        // Notification service
        self.notificationService = notificationService ?? NotificationService()

        // Gamification (must be created before DayPlannerService)
        let gam = GamificationService()
        self.gamificationService = gam

        // Services
        self.authService = authService ?? MockAuthService()
        self.tripService = TripService(repository: localTripRepository)
        self.eventService = EventService(
            repository: localEventRepository,
            notificationService: self.notificationService
        )
        self.dayPlannerService = DayPlannerService(
            taskRepository: localDailyTaskRepository,
            routineRepository: localDailyRoutineRepository,
            gamificationService: gam
        )

        // Sync service
        self.syncService = syncService ?? SyncService(
            localTripRepository: localTripRepository,
            localEventRepository: localEventRepository
        )
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
