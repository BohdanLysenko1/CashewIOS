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

    private var active: any DailyTaskRepositoryProtocol {
        syncService.isEnabled ? remote : local
    }

    func fetchAll() async throws -> [DailyTask] {
        try await active.fetchAll()
    }

    func fetchTasks(for date: Date) async throws -> [DailyTask] {
        try await active.fetchTasks(for: date)
    }

    @discardableResult
    func save(_ task: DailyTask) async throws -> DailyTask {
        try await active.save(task)
    }

    func delete(by id: UUID) async throws {
        try await active.delete(by: id)
    }

    func deleteOlderThan(_ date: Date) async throws {
        try await active.deleteOlderThan(date)
    }
}
