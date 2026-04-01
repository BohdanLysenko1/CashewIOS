import Foundation
import Observation

@Observable
@MainActor
final class DataSyncService {

    // MARK: - State

    private(set) var isDeleting = false
    private(set) var deleteError: String?
    private weak var offlineSyncCoordinator: OfflineSyncCoordinatorProtocol?
    private var offlineStatusObserverToken: UUID?

    private(set) var syncIsOnline = true
    private(set) var syncPendingCount = 0
    private(set) var syncIsFlushing = false
    private(set) var syncLastError: String?
    private(set) var syncLastSuccessfulAt: Date?

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: UserDefaultsKeys.isDataSyncEnabled)
            if isEnabled {
                Task { await offlineSyncCoordinator?.flushIfPossible() }
            }
        }
    }

    // MARK: - Repositories (concrete types for migration)

    private let supabaseTripRepo: SupabaseTripRepository
    private let supabaseEventRepo: SupabaseEventRepository
    private let supabaseTaskRepo: SupabaseDailyTaskRepository
    private let supabaseRoutineRepo: SupabaseDailyRoutineRepository

    private let localTripRepo: LocalTripRepository
    private let localEventRepo: LocalEventRepository
    private let localTaskRepo: LocalDailyTaskRepository
    private let localRoutineRepo: LocalDailyRoutineRepository

    // MARK: - Init

    init(
        supabaseTripRepo: SupabaseTripRepository,
        supabaseEventRepo: SupabaseEventRepository,
        supabaseTaskRepo: SupabaseDailyTaskRepository,
        supabaseRoutineRepo: SupabaseDailyRoutineRepository,
        localTripRepo: LocalTripRepository,
        localEventRepo: LocalEventRepository,
        localTaskRepo: LocalDailyTaskRepository,
        localRoutineRepo: LocalDailyRoutineRepository
    ) {
        self.supabaseTripRepo = supabaseTripRepo
        self.supabaseEventRepo = supabaseEventRepo
        self.supabaseTaskRepo = supabaseTaskRepo
        self.supabaseRoutineRepo = supabaseRoutineRepo
        self.localTripRepo = localTripRepo
        self.localEventRepo = localEventRepo
        self.localTaskRepo = localTaskRepo
        self.localRoutineRepo = localRoutineRepo

        // Default to true (sync enabled) — use object(forKey:) so an absent key stays true
        self.isEnabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.isDataSyncEnabled) as? Bool ?? true
    }

    func attachOfflineSyncCoordinator(_ coordinator: OfflineSyncCoordinatorProtocol) {
        if let token = offlineStatusObserverToken {
            offlineSyncCoordinator?.removeStatusObserver(token)
        }
        self.offlineSyncCoordinator = coordinator
        applySnapshot(coordinator.statusSnapshot)
        offlineStatusObserverToken = coordinator.addStatusObserver { [weak self] snapshot in
            self?.applySnapshot(snapshot)
        }
    }

    // MARK: - Disable & Delete

    /// Migrates all data from Supabase to local storage, bulk-deletes from Supabase,
    /// then sets `isEnabled = false`. Should only be called after user confirms.
    func disableAndDeleteServerData(userId: UUID) async {
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }

        do {
            // 1. Migrate trips
            let trips = try await supabaseTripRepo.fetchAll()
            for trip in trips { try await localTripRepo.save(trip) }

            // 2. Migrate events
            let events = try await supabaseEventRepo.fetchAll()
            for event in events { try await localEventRepo.save(event) }

            // 3. Migrate tasks
            let tasks = try await supabaseTaskRepo.fetchAll()
            for task in tasks { try await localTaskRepo.save(task) }

            // 4. Migrate routines
            let routines = try await supabaseRoutineRepo.fetchAll()
            for routine in routines { try await localRoutineRepo.save(routine) }

            // 5. Bulk-delete from Supabase
            try await supabaseTripRepo.deleteAll(userId: userId)
            try await supabaseEventRepo.deleteAll(userId: userId)
            try await supabaseTaskRepo.deleteAll(userId: userId)
            try await supabaseRoutineRepo.deleteAll(userId: userId)

            // 6. Switch flag — repos will now route to local
            isEnabled = false
            await offlineSyncCoordinator?.clearQueue()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func applySnapshot(_ snapshot: OfflineSyncStatusSnapshot) {
        syncIsOnline = snapshot.isOnline
        syncPendingCount = snapshot.pendingCount
        syncIsFlushing = snapshot.isFlushing
        syncLastError = snapshot.lastSyncError
        syncLastSuccessfulAt = snapshot.lastSuccessfulSyncAt
    }
}
