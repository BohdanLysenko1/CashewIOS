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
    let notificationScheduler: NotificationScheduler
    let syncService: SyncService
    let dataSyncService: DataSyncService
    let offlineSyncCoordinator: OfflineSyncCoordinatorProtocol
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

        // Notification service & scheduler
        let notifService: NotificationServiceProtocol = notificationService ?? NotificationService()
        self.notificationService = notifService
        self.notificationScheduler = NotificationScheduler(notificationService: notifService)

        // Gamification
        let gam = GamificationService()
        self.gamificationService = gam

        // Concrete Supabase repositories (shared across DataSyncService + switchable repos)
        let supabaseTripRepo = SupabaseTripRepository()
        let supabaseEventRepo = SupabaseEventRepository()
        let supabaseTaskRepo = SupabaseDailyTaskRepository()
        let supabaseRoutineRepo = SupabaseDailyRoutineRepository()

        // Concrete local repositories (shared across DataSyncService + switchable repos)
        let localTripRepo = LocalTripRepository()
        let localEventRepo = LocalEventRepository()
        let localTaskRepo = LocalDailyTaskRepository()
        let localRoutineRepo = LocalDailyRoutineRepository()

        // Data sync service — manages the cloud-sync toggle and server-deletion flow
        let dataSync = DataSyncService(
            supabaseTripRepo: supabaseTripRepo,
            supabaseEventRepo: supabaseEventRepo,
            supabaseTaskRepo: supabaseTaskRepo,
            supabaseRoutineRepo: supabaseRoutineRepo,
            localTripRepo: localTripRepo,
            localEventRepo: localEventRepo,
            localTaskRepo: localTaskRepo,
            localRoutineRepo: localRoutineRepo
        )
        self.dataSyncService = dataSync

        // Offline queue + flush orchestrator for eventual cloud sync
        let offlineSync = OfflineSyncCoordinator(
            dataSyncService: dataSync,
            remoteTripRepo: supabaseTripRepo,
            remoteEventRepo: supabaseEventRepo,
            remoteTaskRepo: supabaseTaskRepo,
            remoteRoutineRepo: supabaseRoutineRepo,
            localTripRepo: localTripRepo,
            localEventRepo: localEventRepo,
            localTaskRepo: localTaskRepo,
            localRoutineRepo: localRoutineRepo
        )
        self.offlineSyncCoordinator = offlineSync
        dataSync.attachOfflineSyncCoordinator(offlineSync)

        // Offline-first repositories — always local-first, queue cloud writes when enabled.
        let tripRepo = tripRepository ?? SwitchableTripRepository(
            remote: supabaseTripRepo,
            local: localTripRepo,
            syncService: dataSync,
            syncCoordinator: offlineSync
        )
        let eventRepo = eventRepository ?? SwitchableEventRepository(
            remote: supabaseEventRepo,
            local: localEventRepo,
            syncService: dataSync,
            syncCoordinator: offlineSync
        )
        let taskRepo = dailyTaskRepository ?? SwitchableDailyTaskRepository(
            remote: supabaseTaskRepo,
            local: localTaskRepo,
            syncService: dataSync,
            syncCoordinator: offlineSync
        )
        let routineRepo = dailyRoutineRepository ?? SwitchableDailyRoutineRepository(
            remote: supabaseRoutineRepo,
            local: localRoutineRepo,
            syncService: dataSync,
            syncCoordinator: offlineSync
        )

        // Services
        self.tripService = TripService(repository: tripRepo, notificationScheduler: self.notificationScheduler)
        self.eventService = EventService(
            repository: eventRepo,
            notificationService: self.notificationService
        )
        self.dayPlannerService = DayPlannerService(
            taskRepository: taskRepo,
            routineRepository: routineRepo,
            gamificationService: gam,
            notificationScheduler: self.notificationScheduler
        )

        // Sync (CloudKit fallback / local backup) — unchanged
        self.syncService = syncService ?? SyncService(
            localTripRepository: localTripRepo,
            localEventRepository: localEventRepo
        )

        // Sharing
        self.shareService = ShareService(authService: auth)
    }

    // MARK: - Factory Methods

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(authService: authService)
    }

    // MARK: - App Lifecycle

    func requestNotificationPermission() async -> Bool {
        await notificationService.requestAuthorization()
    }
}
