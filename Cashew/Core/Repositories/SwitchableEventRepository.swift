import Foundation

/// Routes event persistence to Supabase (sync on) or local JSON (sync off)
/// based on `DataSyncService.isEnabled` at the time of each call.
@MainActor
final class SwitchableEventRepository: EventRepositoryProtocol {

    private let remote: SupabaseEventRepository
    private let local: LocalEventRepository
    private let syncService: DataSyncService

    init(remote: SupabaseEventRepository, local: LocalEventRepository, syncService: DataSyncService) {
        self.remote = remote
        self.local = local
        self.syncService = syncService
    }

    func fetchAll() async throws -> [Event] {
        syncService.isEnabled ? try await remote.fetchAll() : try await local.fetchAll()
    }

    func fetch(by id: UUID) async throws -> Event {
        syncService.isEnabled ? try await remote.fetch(by: id) : try await local.fetch(by: id)
    }

    @discardableResult
    func save(_ event: Event) async throws -> Event {
        syncService.isEnabled ? try await remote.save(event) : try await local.save(event)
    }

    func delete(by id: UUID) async throws {
        syncService.isEnabled ? try await remote.delete(by: id) : try await local.delete(by: id)
    }
}
