import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class TripService: TripServiceProtocol {

    private let repository: TripRepositoryProtocol

    private(set) var trips: [Trip] = []

    // Realtime
    private var syncTask: Task<Void, Never>?

    init(repository: TripRepositoryProtocol) {
        self.repository = repository
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
                    _ = try await repository.save(trips[i])
                } catch {
                    print("[TripService] Status sync failed for '\(trips[i].name)': \(error)")
                }
            }
        }
    }

    // MARK: - CRUD

    func createTrip(_ trip: Trip) async throws {
        let saved = try await repository.save(trip)
        trips.append(saved)
        sortTrips()
    }

    func updateTrip(_ trip: Trip) async throws {
        let saved = try await repository.save(trip)
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = saved
            sortTrips()
        }
    }

    func deleteTrip(by id: UUID) async throws {
        try await repository.delete(by: id)
        trips.removeAll { $0.id == id }
    }

    func trip(by id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }

    private func sortTrips() {
        trips.sort { $0.startDate < $1.startDate }
    }

    // MARK: - Realtime Sync

    func startRealtimeSync() {
        guard syncTask == nil else { return }

        syncTask = Task {
            let channel = SupabaseManager.client.channel("trips-sync")
            let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "trips")
            let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "trips")
            let deletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "trips")

            do { try await channel.subscribeWithError() }
            catch { print("[TripService] Realtime subscription failed: \(error)") }

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
        } catch {
            print("[TripService] Failed to fetch updated trip \(id): \(error)")
        }
    }

    private func handleDelete(_ action: DeleteAction) async {
        guard let id = extractUUID(from: action.oldRecord) else { return }
        trips.removeAll { $0.id == id }
    }

    private func extractUUID(from record: [String: AnyJSON]) -> UUID? {
        guard case .string(let str) = record["id"] else { return nil }
        return UUID(uuidString: str)
    }
}
