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

    private var active: any EventRepositoryProtocol {
        syncService.isEnabled ? remote : local
    }

    func fetchAll() async throws -> [Event] {
        try await active.fetchAll()
    }

    func fetch(by id: UUID) async throws -> Event {
        try await active.fetch(by: id)
    }

    @discardableResult
    func save(_ event: Event) async throws -> Event {
        try await active.save(event)
    }

    func delete(by id: UUID) async throws {
        try await active.delete(by: id)
    }
}
