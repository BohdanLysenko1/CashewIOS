import Foundation

actor LocalEventRepository: EventRepositoryProtocol {

    private let fileURL: URL
    private var cache: [UUID: Event] = [:]
    private var isLoaded = false

    init(fileManager: FileManager = .default) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
        self.fileURL = documentsDirectory.appendingPathComponent("events.json")
    }

    func fetchAll() async throws -> [Event] {
        try await loadIfNeeded()
        return Array(cache.values).sorted { $0.date < $1.date }
    }

    func fetch(by id: UUID) async throws -> Event {
        try await loadIfNeeded()
        guard let event = cache[id] else {
            throw RepositoryError.notFound
        }
        return event
    }

    @discardableResult
    func save(_ event: Event) async throws -> Event {
        try await loadIfNeeded()
        var updatedEvent = event
        updatedEvent.updatedAt = Date()
        cache[event.id] = updatedEvent
        try await persist()
        return updatedEvent
    }

    @discardableResult
    func saveFromSync(_ event: Event) async throws -> Event {
        try await loadIfNeeded()
        cache[event.id] = event
        try await persist()
        return event
    }

    func delete(by id: UUID) async throws {
        try await loadIfNeeded()
        guard cache.removeValue(forKey: id) != nil else {
            throw RepositoryError.notFound
        }
        try await persist()
    }

    func replaceAll(_ events: [Event]) async throws {
        try await loadIfNeeded()
        cache = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
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
            let events = try JSONDecoder().decode([Event].self, from: data)
            cache = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
            isLoaded = true
        } catch {
            throw RepositoryError.loadFailed(underlying: error)
        }
    }

    private func persist() async throws {
        do {
            let events = Array(cache.values)
            let data = try JSONEncoder().encode(events)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
    }
}
