import Foundation
import Observation

@Observable
@MainActor
final class TripService: TripServiceProtocol {

    private let repository: TripRepositoryProtocol

    private(set) var trips: [Trip] = []

    init(repository: TripRepositoryProtocol) {
        self.repository = repository
    }

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
                    print("[TripService] Failed to persist status sync for trip '\(trips[i].name)': \(error)")
                }
            }
        }
    }

    func createTrip(_ trip: Trip) async throws {
        let savedTrip = try await repository.save(trip)
        trips.append(savedTrip)
        sortTrips()
    }

    func updateTrip(_ trip: Trip) async throws {
        let savedTrip = try await repository.save(trip)
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = savedTrip
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
}
