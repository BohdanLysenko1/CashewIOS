import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class TripService: TripServiceProtocol {

    private let repository: TripRepositoryProtocol
    private let notificationScheduler: NotificationScheduler?

    private(set) var trips: [Trip] = []
    private(set) var realtimeEventCounter = 0
    private(set) var realtimeIndicatorMessage: String?
    private(set) var realtimeChangedTripId: UUID?

    // Realtime
    private var syncTask: Task<Void, Never>?
    private var syncChannel: RealtimeChannelV2?
    private struct LocalMutation {
        let observedAt: Date
        let savedUpdatedAt: Date?
    }

    private var recentLocalMutations: [UUID: LocalMutation] = [:]
    private let localMutationSuppressionWindow: TimeInterval = 120
    private let localMutationTimestampTolerance: TimeInterval = 2

    init(repository: TripRepositoryProtocol, notificationScheduler: NotificationScheduler? = nil) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
    }

    // MARK: - Load

    func loadTrips() async throws {
        trips = try await repository.fetchAll()
        await syncStatuses()
    }

    private func syncStatuses() async {
        for i in trips.indices {
            let computed = trips[i].computedStatus
            if trips[i].status != computed {
                trips[i].status = computed
                do {
                    let saved = try await repository.save(trips[i])
                    registerLocalMutation(saved.id, updatedAt: saved.updatedAt)
                    trips[i] = saved
                } catch {
                    print("[TripService] Status sync failed for '\(trips[i].name)': \(error)")
                }
            }
        }
    }

    // MARK: - CRUD

    func createTrip(_ trip: Trip) async throws {
        let saved = try await repository.save(trip)
        registerLocalMutation(saved.id, updatedAt: saved.updatedAt)
        trips.append(saved)
        sortTrips()
        await notificationScheduler?.rescheduleTripNotifications(trips: trips)
    }

    func updateTrip(_ trip: Trip) async throws {
        let existingIndex = trips.firstIndex(where: { $0.id == trip.id })
        let previousTrip = existingIndex.map { trips[$0] }

        // Optimistic update so section edits appear immediately.
        if let index = existingIndex {
            trips[index] = trip
        } else {
            trips.append(trip)
        }
        sortTrips()

        do {
            let saved = try await repository.save(trip)
            registerLocalMutation(saved.id, updatedAt: saved.updatedAt)

            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index] = saved
            } else {
                trips.append(saved)
            }
            sortTrips()

            await notificationScheduler?.rescheduleTripNotifications(trips: trips)
        } catch {
            // Roll back optimistic state on persistence failure.
            if let previousTrip {
                if let index = trips.firstIndex(where: { $0.id == previousTrip.id }) {
                    trips[index] = previousTrip
                } else {
                    trips.append(previousTrip)
                }
            } else {
                trips.removeAll { $0.id == trip.id }
            }
            sortTrips()
            throw error
        }
    }

    func deleteTrip(by id: UUID) async throws {
        try await repository.delete(by: id)
        registerLocalMutation(id)
        trips.removeAll { $0.id == id }
        await notificationScheduler?.rescheduleTripNotifications(trips: trips)
    }

    func trip(by id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }

    private func sortTrips() {
        trips.sort { $0.startDate < $1.startDate }
    }

    // MARK: - Realtime Sync

    func startRealtimeSync(ownerID: UUID) {
        guard syncTask == nil else { return }

        let filter = "owner_id=eq.\(ownerID.uuidString)"
        let channel = SupabaseManager.client.channel("trips-sync")
        // Register postgres changes synchronously before subscribing, filtered to this user's rows
        let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "trips", filter: filter)
        let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "trips", filter: filter)
        let deletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "trips", filter: filter)
        syncChannel = channel

        syncTask = Task {
            do {
                try await channel.subscribeWithError()
            } catch {
                print("[TripService] Realtime subscription failed: \(error)")
                return
            }

            await withTaskGroup(of: Void.self) { group in
                group.addTask { for await action in inserts { await self.handleInsert(action) } }
                group.addTask { for await action in updates { await self.handleUpdate(action) } }
                group.addTask { for await action in deletes { await self.handleDelete(action) } }
            }
        }
    }

    func stopRealtimeSync() {
        syncTask?.cancel()
        syncTask = nil
        if let channel = syncChannel {
            syncChannel = nil
            Task { await SupabaseManager.client.removeChannel(channel) }
        }
    }

    // MARK: - Realtime Handlers

    private func handleInsert(_ action: InsertAction) async {
        guard let id = extractUUID(from: action.record) else { return }
        // Only add if not already present (might be our own insert)
        guard !trips.contains(where: { $0.id == id }) else { return }
        do {
            let trip = try await repository.fetch(by: id)
            trips.append(trip)
            sortTrips()
            if shouldAnnounceRemoteMutation(for: id) {
                announceRealtimeChange("New shared trip added", changedId: id)
            }
        } catch {
            print("[TripService] Failed to fetch inserted trip \(id): \(error)")
        }
    }

    private func handleUpdate(_ action: UpdateAction) async {
        guard let id = extractUUID(from: action.record) else { return }
        do {
            let trip = try await repository.fetch(by: id)
            if let index = trips.firstIndex(where: { $0.id == id }) {
                trips[index] = trip
            } else {
                // Shared with us mid-session
                trips.append(trip)
            }
            sortTrips()
            if shouldAnnounceRemoteMutation(for: id, remoteUpdatedAt: trip.updatedAt) {
                announceRealtimeChange("Trip updated by collaborator", changedId: id)
            }
        } catch {
            print("[TripService] Failed to fetch updated trip \(id): \(error)")
        }
    }

    private func handleDelete(_ action: DeleteAction) async {
        guard let id = extractUUID(from: action.oldRecord) else { return }
        trips.removeAll { $0.id == id }
        if shouldAnnounceRemoteMutation(for: id) {
            announceRealtimeChange("Shared trip removed", changedId: nil)
        }
    }

    private func extractUUID(from record: [String: AnyJSON]) -> UUID? {
        guard case .string(let str) = record["id"] else { return nil }
        return UUID(uuidString: str)
    }

    private func registerLocalMutation(_ id: UUID, updatedAt: Date? = nil) {
        pruneLocalMutations()
        recentLocalMutations[id] = LocalMutation(
            observedAt: Date(),
            savedUpdatedAt: updatedAt
        )
    }

    private func shouldAnnounceRemoteMutation(for id: UUID, remoteUpdatedAt: Date? = nil) -> Bool {
        pruneLocalMutations()
        guard let mutation = recentLocalMutations[id] else { return true }

        if let remoteUpdatedAt, let localUpdatedAt = mutation.savedUpdatedAt {
            if abs(remoteUpdatedAt.timeIntervalSince(localUpdatedAt)) <= localMutationTimestampTolerance {
                recentLocalMutations.removeValue(forKey: id)
                return false
            }

            // A newer/different update for the same entity arrived.
            recentLocalMutations.removeValue(forKey: id)
            return true
        }

        if Date().timeIntervalSince(mutation.observedAt) < localMutationSuppressionWindow {
            recentLocalMutations.removeValue(forKey: id)
            return false
        }
        recentLocalMutations.removeValue(forKey: id)
        return true
    }

    private func pruneLocalMutations() {
        let cutoff = Date().addingTimeInterval(-localMutationSuppressionWindow)
        recentLocalMutations = recentLocalMutations.filter { $0.value.observedAt > cutoff }
    }

    private func announceRealtimeChange(_ message: String, changedId: UUID?) {
        realtimeChangedTripId = changedId
        realtimeIndicatorMessage = message
        realtimeEventCounter += 1
    }
}
