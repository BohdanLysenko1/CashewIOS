import Foundation

actor LocalTripRepository: TripRepositoryProtocol {

    private let fileURL: URL
    private var cache: [UUID: Trip] = [:]
    private var isLoaded = false

    init(fileManager: FileManager = .default) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
        self.fileURL = documentsDirectory.appendingPathComponent("trips.json")
    }

    func fetchAll() async throws -> [Trip] {
        try await loadIfNeeded()
        return Array(cache.values).sorted { $0.startDate < $1.startDate }
    }

    func fetch(by id: UUID) async throws -> Trip {
        try await loadIfNeeded()
        guard let trip = cache[id] else {
            throw RepositoryError.notFound
        }
        return trip
    }

    @discardableResult
    func save(_ trip: Trip) async throws -> Trip {
        try await loadIfNeeded()
        var updatedTrip = trip
        updatedTrip.updatedAt = Date()
        cache[trip.id] = updatedTrip
        try await persist()
        return updatedTrip
    }

    @discardableResult
    func saveFromSync(_ trip: Trip) async throws -> Trip {
        try await loadIfNeeded()
        cache[trip.id] = trip
        try await persist()
        return trip
    }

    func delete(by id: UUID) async throws {
        try await loadIfNeeded()
        guard cache.removeValue(forKey: id) != nil else {
            throw RepositoryError.notFound
        }
        try await persist()
    }

    func replaceAll(_ trips: [Trip]) async throws {
        try await loadIfNeeded()
        cache = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })
        try await persist()
    }

    private func loadIfNeeded() async throws {
        guard !isLoaded else { return }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            isLoaded = true
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let trips = try JSONDecoder().decode([Trip].self, from: data)
            cache = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })
            isLoaded = true
        } catch {
            throw RepositoryError.loadFailed(underlying: error)
        }
    }

    private func persist() async throws {
        do {
            let trips = Array(cache.values)
            let data = try JSONEncoder().encode(trips)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
    }
}
