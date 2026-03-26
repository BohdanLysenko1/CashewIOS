import Foundation

/// Routes trip persistence to Supabase (sync on) or local JSON (sync off)
/// based on `DataSyncService.isEnabled` at the time of each call.
@MainActor
final class SwitchableTripRepository: TripRepositoryProtocol {

    private let remote: SupabaseTripRepository
    private let local: LocalTripRepository
    private let syncService: DataSyncService

    init(remote: SupabaseTripRepository, local: LocalTripRepository, syncService: DataSyncService) {
        self.remote = remote
        self.local = local
        self.syncService = syncService
    }

    private var active: any TripRepositoryProtocol {
        syncService.isEnabled ? remote : local
    }

    func fetchAll() async throws -> [Trip] {
        try await active.fetchAll()
    }

    func fetch(by id: UUID) async throws -> Trip {
        try await active.fetch(by: id)
    }

    @discardableResult
    func save(_ trip: Trip) async throws -> Trip {
        try await active.save(trip)
    }

    func delete(by id: UUID) async throws {
        try await active.delete(by: id)
    }
}
