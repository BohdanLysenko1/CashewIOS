import Foundation

actor LocalDailyRoutineRepository: DailyRoutineRepositoryProtocol {

    private let fileURL: URL
    private var cache: [UUID: DailyRoutine] = [:]
    private var isLoaded = false

    init(fileManager: FileManager = .default) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
        self.fileURL = documentsDirectory.appendingPathComponent("daily_routines.json")
    }

    func fetchAll() async throws -> [DailyRoutine] {
        try await loadIfNeeded()
        return Array(cache.values).sorted { $0.createdAt < $1.createdAt }
    }

    func fetch(by id: UUID) async throws -> DailyRoutine {
        try await loadIfNeeded()
        guard let routine = cache[id] else {
            throw RepositoryError.notFound
        }
        return routine
    }

    @discardableResult
    func save(_ routine: DailyRoutine) async throws -> DailyRoutine {
        try await loadIfNeeded()
        var updatedRoutine = routine
        updatedRoutine.updatedAt = Date()
        cache[routine.id] = updatedRoutine
        try await persist()
        return updatedRoutine
    }

    @discardableResult
    func saveFromSync(_ routine: DailyRoutine) async throws -> DailyRoutine {
        try await loadIfNeeded()
        cache[routine.id] = routine
        try await persist()
        return routine
    }

    func delete(by id: UUID) async throws {
        try await loadIfNeeded()
        guard cache.removeValue(forKey: id) != nil else {
            throw RepositoryError.notFound
        }
        try await persist()
    }

    func replaceAll(_ routines: [DailyRoutine]) async throws {
        try await loadIfNeeded()
        cache = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        try await persist()
    }

    // MARK: - Private

    private func loadIfNeeded() async throws {
        guard !isLoaded else { return }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            isLoaded = true
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let routines = try JSONDecoder().decode([DailyRoutine].self, from: data)
            cache = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
            isLoaded = true
        } catch {
            throw RepositoryError.loadFailed(underlying: error)
        }
    }

    private func persist() async throws {
        do {
            let routines = Array(cache.values)
            let data = try JSONEncoder().encode(routines)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
    }
}
