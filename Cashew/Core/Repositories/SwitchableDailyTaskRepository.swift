import Foundation

/// Routes daily task persistence to Supabase (sync on) or local JSON (sync off)
/// based on `DataSyncService.isEnabled` at the time of each call.
@MainActor
final class SwitchableDailyTaskRepository: DailyTaskRepositoryProtocol {

    private let remote: SupabaseDailyTaskRepository
    private let local: LocalDailyTaskRepository
    private let syncService: DataSyncService

    init(remote: SupabaseDailyTaskRepository, local: LocalDailyTaskRepository, syncService: DataSyncService) {
        self.remote = remote
        self.local = local
        self.syncService = syncService
    }

    func fetchAll() async throws -> [DailyTask] {
        syncService.isEnabled ? try await remote.fetchAll() : try await local.fetchAll()
    }

    func fetchTasks(for date: Date) async throws -> [DailyTask] {
        syncService.isEnabled ? try await remote.fetchTasks(for: date) : try await local.fetchTasks(for: date)
    }

    @discardableResult
    func save(_ task: DailyTask) async throws -> DailyTask {
        syncService.isEnabled ? try await remote.save(task) : try await local.save(task)
    }

    func delete(by id: UUID) async throws {
        syncService.isEnabled ? try await remote.delete(by: id) : try await local.delete(by: id)
    }

    func deleteOlderThan(_ date: Date) async throws {
        syncService.isEnabled ? try await remote.deleteOlderThan(date) : try await local.deleteOlderThan(date)
    }
}
