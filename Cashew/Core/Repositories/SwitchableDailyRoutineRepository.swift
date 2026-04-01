import Foundation

/// Offline-first daily routine repository:
/// - Always reads/writes local cache
/// - Queues cloud mutations when sync is enabled
/// - Flushes queued operations when network is available
@MainActor
final class SwitchableDailyRoutineRepository: DailyRoutineRepositoryProtocol, @unchecked Sendable {

    private let remote: SupabaseDailyRoutineRepository
    private let local: LocalDailyRoutineRepository
    private let syncService: DataSyncService
    private let syncCoordinator: OfflineSyncCoordinatorProtocol

    init(
        remote: SupabaseDailyRoutineRepository,
        local: LocalDailyRoutineRepository,
        syncService: DataSyncService,
        syncCoordinator: OfflineSyncCoordinatorProtocol
    ) {
        self.remote = remote
        self.local = local
        self.syncService = syncService
        self.syncCoordinator = syncCoordinator
    }

    func fetchAll() async throws -> [DailyRoutine] {
        let localRoutines = try await local.fetchAll()
        guard syncService.isEnabled else { return localRoutines }
        guard syncCoordinator.isOnline else { return localRoutines }
        await syncCoordinator.flushIfPossible()

        do {
            let remoteRoutines = try await remote.fetchAll()
            try await local.replaceAll(remoteRoutines)
            return try await local.fetchAll()
        } catch {
            return localRoutines
        }
    }

    @discardableResult
    func save(_ routine: DailyRoutine) async throws -> DailyRoutine {
        let localSaved = try await local.save(routine)
        guard syncService.isEnabled else { return localSaved }

        await syncCoordinator.enqueueUpsert(.dailyRoutine(localSaved))
        await syncCoordinator.flushIfPossible()

        return (try? await local.fetch(by: localSaved.id)) ?? localSaved
    }

    func delete(by id: UUID) async throws {
        try await local.delete(by: id)
        guard syncService.isEnabled else { return }

        await syncCoordinator.enqueueDelete(entityType: .dailyRoutine, entityID: id)
        await syncCoordinator.flushIfPossible()
    }
}
