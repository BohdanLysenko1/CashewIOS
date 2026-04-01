import Foundation

/// Offline-first daily task repository:
/// - Always reads/writes local cache
/// - Queues cloud mutations when sync is enabled
/// - Flushes queued operations when network is available
@MainActor
final class SwitchableDailyTaskRepository: DailyTaskRepositoryProtocol, @unchecked Sendable {

    private let remote: SupabaseDailyTaskRepository
    private let local: LocalDailyTaskRepository
    private let syncService: DataSyncService
    private let syncCoordinator: OfflineSyncCoordinatorProtocol

    init(
        remote: SupabaseDailyTaskRepository,
        local: LocalDailyTaskRepository,
        syncService: DataSyncService,
        syncCoordinator: OfflineSyncCoordinatorProtocol
    ) {
        self.remote = remote
        self.local = local
        self.syncService = syncService
        self.syncCoordinator = syncCoordinator
    }

    func fetchAll() async throws -> [DailyTask] {
        let localTasks = try await local.fetchAll()
        guard syncService.isEnabled else { return localTasks }
        guard syncCoordinator.isOnline else { return localTasks }
        await syncCoordinator.flushIfPossible()

        do {
            let remoteTasks = try await remote.fetchAll()
            try await local.replaceAll(remoteTasks)
            return try await local.fetchAll()
        } catch {
            return localTasks
        }
    }

    func fetchTasks(for date: Date) async throws -> [DailyTask] {
        let localTasks = try await local.fetchTasks(for: date)
        guard syncService.isEnabled else { return localTasks }
        guard syncCoordinator.isOnline else { return localTasks }
        await syncCoordinator.flushIfPossible()

        do {
            let remoteTasks = try await remote.fetchTasks(for: date)
            try await local.replaceTasks(on: date, with: remoteTasks)
            return try await local.fetchTasks(for: date)
        } catch {
            return localTasks
        }
    }

    @discardableResult
    func save(_ task: DailyTask) async throws -> DailyTask {
        let localSaved = try await local.save(task)
        guard syncService.isEnabled else { return localSaved }

        await syncCoordinator.enqueueUpsert(.dailyTask(localSaved))
        await syncCoordinator.flushIfPossible()

        return (try? await local.fetch(by: localSaved.id)) ?? localSaved
    }

    func delete(by id: UUID) async throws {
        try await local.delete(by: id)
        guard syncService.isEnabled else { return }

        await syncCoordinator.enqueueDelete(entityType: .dailyTask, entityID: id)
        await syncCoordinator.flushIfPossible()
    }

    func deleteOlderThan(_ date: Date) async throws {
        try await local.deleteOlderThan(date)
        guard syncService.isEnabled, syncCoordinator.isOnline else { return }

        // Cleanup jobs are best-effort when cloud sync is on.
        do {
            try await remote.deleteOlderThan(date)
        } catch {
            // Intentionally ignored. Older cleanup can be retried in a future online session.
        }
    }
}
