import Foundation

/// Routes daily routine persistence to Supabase (sync on) or local JSON (sync off)
/// based on `DataSyncService.isEnabled` at the time of each call.
@MainActor
final class SwitchableDailyRoutineRepository: DailyRoutineRepositoryProtocol {

    private let remote: SupabaseDailyRoutineRepository
    private let local: LocalDailyRoutineRepository
    private let syncService: DataSyncService

    init(remote: SupabaseDailyRoutineRepository, local: LocalDailyRoutineRepository, syncService: DataSyncService) {
        self.remote = remote
        self.local = local
        self.syncService = syncService
    }

    private var active: any DailyRoutineRepositoryProtocol {
        syncService.isEnabled ? remote : local
    }

    func fetchAll() async throws -> [DailyRoutine] {
        try await active.fetchAll()
    }

    @discardableResult
    func save(_ routine: DailyRoutine) async throws -> DailyRoutine {
        try await active.save(routine)
    }

    func delete(by id: UUID) async throws {
        try await active.delete(by: id)
    }
}
