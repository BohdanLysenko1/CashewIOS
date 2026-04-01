import Foundation

/// Offline-first trip repository:
/// - Always reads/writes local cache
/// - Queues cloud mutations when sync is enabled
/// - Flushes queued operations when network is available
@MainActor
final class SwitchableTripRepository: TripRepositoryProtocol {

    private let remote: SupabaseTripRepository
    private let local: LocalTripRepository
    private let syncService: DataSyncService
    private let syncCoordinator: OfflineSyncCoordinatorProtocol

    init(
        remote: SupabaseTripRepository,
        local: LocalTripRepository,
        syncService: DataSyncService,
        syncCoordinator: OfflineSyncCoordinatorProtocol
    ) {
        self.remote = remote
        self.local = local
        self.syncService = syncService
        self.syncCoordinator = syncCoordinator
    }

    func fetchAll() async throws -> [Trip] {
        let localTrips = try await local.fetchAll()
        guard syncService.isEnabled else { return localTrips }
        guard syncCoordinator.isOnline else { return localTrips }
        await syncCoordinator.flushIfPossible()

        do {
            let remoteTrips = try await remote.fetchAll()
            try await local.replaceAll(remoteTrips)
            return remoteTrips.sorted { $0.startDate < $1.startDate }
        } catch {
            return localTrips
        }
    }

    func fetch(by id: UUID) async throws -> Trip {
        if syncService.isEnabled, syncCoordinator.isOnline {
            await syncCoordinator.flushIfPossible()
        }

        do {
            let localTrip = try await local.fetch(by: id)
            guard syncService.isEnabled, syncCoordinator.isOnline else { return localTrip }

            if let remoteTrip = try? await remote.fetch(by: id) {
                _ = try? await local.saveFromSync(remoteTrip)
                return remoteTrip
            }
            return localTrip
        } catch {
            guard syncService.isEnabled, syncCoordinator.isOnline else { throw error }
            let remoteTrip = try await remote.fetch(by: id)
            _ = try? await local.saveFromSync(remoteTrip)
            return remoteTrip
        }
    }

    @discardableResult
    func save(_ trip: Trip) async throws -> Trip {
        let localSaved = try await local.save(trip)
        guard syncService.isEnabled else { return localSaved }

        await syncCoordinator.enqueueUpsert(.trip(localSaved))
        await syncCoordinator.flushIfPossible()

        return (try? await local.fetch(by: localSaved.id)) ?? localSaved
    }

    func delete(by id: UUID) async throws {
        try await local.delete(by: id)
        guard syncService.isEnabled else { return }

        await syncCoordinator.enqueueDelete(entityType: .trip, entityID: id)
        await syncCoordinator.flushIfPossible()
    }
}
