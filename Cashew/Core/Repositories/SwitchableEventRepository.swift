import Foundation

/// Offline-first event repository:
/// - Always reads/writes local cache
/// - Queues cloud mutations when sync is enabled
/// - Flushes queued operations when network is available
@MainActor
final class SwitchableEventRepository: EventRepositoryProtocol {

    private let remote: SupabaseEventRepository
    private let local: LocalEventRepository
    private let syncService: DataSyncService
    private let syncCoordinator: OfflineSyncCoordinatorProtocol

    init(
        remote: SupabaseEventRepository,
        local: LocalEventRepository,
        syncService: DataSyncService,
        syncCoordinator: OfflineSyncCoordinatorProtocol
    ) {
        self.remote = remote
        self.local = local
        self.syncService = syncService
        self.syncCoordinator = syncCoordinator
    }

    func fetchAll() async throws -> [Event] {
        let localEvents = try await local.fetchAll()
        guard syncService.isEnabled else { return localEvents }
        guard syncCoordinator.isOnline else { return localEvents }
        await syncCoordinator.flushIfPossible()

        do {
            let remoteEvents = try await remote.fetchAll()
            try await local.replaceAll(remoteEvents)
            return remoteEvents.sorted { $0.date < $1.date }
        } catch {
            return localEvents
        }
    }

    func fetch(by id: UUID) async throws -> Event {
        if syncService.isEnabled, syncCoordinator.isOnline {
            await syncCoordinator.flushIfPossible()
        }

        do {
            let localEvent = try await local.fetch(by: id)
            guard syncService.isEnabled, syncCoordinator.isOnline else { return localEvent }

            if let remoteEvent = try? await remote.fetch(by: id) {
                _ = try? await local.saveFromSync(remoteEvent)
                return remoteEvent
            }
            return localEvent
        } catch {
            guard syncService.isEnabled, syncCoordinator.isOnline else { throw error }
            let remoteEvent = try await remote.fetch(by: id)
            _ = try? await local.saveFromSync(remoteEvent)
            return remoteEvent
        }
    }

    @discardableResult
    func save(_ event: Event) async throws -> Event {
        let localSaved = try await local.save(event)
        guard syncService.isEnabled else { return localSaved }

        await syncCoordinator.enqueueUpsert(.event(localSaved))
        await syncCoordinator.flushIfPossible()

        return (try? await local.fetch(by: localSaved.id)) ?? localSaved
    }

    func delete(by id: UUID) async throws {
        try await local.delete(by: id)
        guard syncService.isEnabled else { return }

        await syncCoordinator.enqueueDelete(entityType: .event, entityID: id)
        await syncCoordinator.flushIfPossible()
    }
}
