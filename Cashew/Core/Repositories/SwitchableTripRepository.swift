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

    func fetchAll() async throws -> [Trip] {
        syncService.isEnabled ? try await remote.fetchAll() : try await local.fetchAll()
    }

    func fetch(by id: UUID) async throws -> Trip {
        syncService.isEnabled ? try await remote.fetch(by: id) : try await local.fetch(by: id)
    }

    @discardableResult
    func save(_ trip: Trip) async throws -> Trip {
        syncService.isEnabled ? try await remote.save(trip) : try await local.save(trip)
    }

    func delete(by id: UUID) async throws {
        syncService.isEnabled ? try await remote.delete(by: id) : try await local.delete(by: id)
    }
}
