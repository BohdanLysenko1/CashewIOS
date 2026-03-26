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

    func fetchAll() async throws -> [DailyRoutine] {
        syncService.isEnabled ? try await remote.fetchAll() : try await local.fetchAll()
    }

    @discardableResult
    func save(_ routine: DailyRoutine) async throws -> DailyRoutine {
        syncService.isEnabled ? try await remote.save(routine) : try await local.save(routine)
    }

    func delete(by id: UUID) async throws {
        syncService.isEnabled ? try await remote.delete(by: id) : try await local.delete(by: id)
    }
}
