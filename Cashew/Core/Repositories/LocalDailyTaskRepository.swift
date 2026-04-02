import Foundation

actor LocalDailyTaskRepository: DailyTaskRepositoryProtocol {

    private let fileURL: URL
    private var cache: [UUID: DailyTask] = [:]
    private var isLoaded = false

    init(fileManager: FileManager = .default) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
        self.fileURL = documentsDirectory.appendingPathComponent("daily_tasks.json")
    }

    func fetchAll() async throws -> [DailyTask] {
        try await loadIfNeeded()
        return Array(cache.values).sorted { task1, task2 in
            // Sort by date, then by start time, then by creation time
            if !Calendar.current.isDate(task1.date, inSameDayAs: task2.date) {
                return task1.date < task2.date
            }
            if let time1 = task1.startTime, let time2 = task2.startTime {
                return time1 < time2
            }
            if task1.startTime != nil { return true }
            if task2.startTime != nil { return false }
            return task1.createdAt < task2.createdAt
        }
    }

    func fetchTasks(for date: Date) async throws -> [DailyTask] {
        try await loadIfNeeded()
        let calendar = Calendar.current

        return cache.values
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { task1, task2 in
                // Scheduled tasks first, sorted by time
                if let time1 = task1.startTime, let time2 = task2.startTime {
                    return time1 < time2
                }
                if task1.startTime != nil { return true }
                if task2.startTime != nil { return false }
                // Unscheduled: incomplete first, then by creation time
                if task1.isCompleted != task2.isCompleted {
                    return !task1.isCompleted
                }
                return task1.createdAt < task2.createdAt
            }
    }

    func fetch(by id: UUID) async throws -> DailyTask {
        try await loadIfNeeded()
        guard let task = cache[id] else {
            throw RepositoryError.notFound
        }
        return task
    }

    @discardableResult
    func save(_ task: DailyTask) async throws -> DailyTask {
        try await loadIfNeeded()
        var updatedTask = task
        updatedTask.updatedAt = Date()
        cache[task.id] = updatedTask
        try await persist()
        return updatedTask
    }

    @discardableResult
    func saveFromSync(_ task: DailyTask) async throws -> DailyTask {
        try await loadIfNeeded()
        cache[task.id] = task
        try await persist()
        return task
    }

    func delete(by id: UUID) async throws {
        try await loadIfNeeded()
        guard cache.removeValue(forKey: id) != nil else {
            throw RepositoryError.notFound
        }
        try await persist()
    }

    func deleteOlderThan(_ date: Date) async throws {
        try await loadIfNeeded()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let idsToRemove = cache.values
            .filter { calendar.startOfDay(for: $0.date) < startOfDay }
            .map { $0.id }

        for id in idsToRemove {
            cache.removeValue(forKey: id)
        }

        if !idsToRemove.isEmpty {
            try await persist()
        }
    }

    func replaceAll(_ tasks: [DailyTask]) async throws {
        try await loadIfNeeded()
        cache = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        try await persist()
    }

    func replaceTasks(on date: Date, with tasks: [DailyTask]) async throws {
        try await loadIfNeeded()
        let calendar = Calendar.current

        cache = cache.filter { _, task in
            !calendar.isDate(task.date, inSameDayAs: date)
        }

        for task in tasks {
            cache[task.id] = task
        }

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
            let tasks = try JSONDecoder().decode([DailyTask].self, from: data)
            cache = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
            isLoaded = true
        } catch {
            throw RepositoryError.loadFailed(underlying: error)
        }
    }

    private func persist() async throws {
        do {
            let tasks = Array(cache.values)
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
    }
}
