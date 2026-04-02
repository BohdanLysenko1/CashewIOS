import Foundation

actor OfflineSyncQueueStore {

    private let fileURL: URL
    private var operations: [SyncOperation] = []
    private var isLoaded = false

    init(fileManager: FileManager = .default) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
        self.fileURL = documentsDirectory.appendingPathComponent("offline_sync_queue.json")
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func enqueue(_ operation: SyncOperation) async throws {
        try await loadIfNeeded()
        coalesce(operation)
        try await persist()
    }

    func remove(id: UUID) async throws {
        try await loadIfNeeded()
        operations.removeAll { $0.id == id }
        try await persist()
    }

    func update(_ operation: SyncOperation) async throws {
        try await loadIfNeeded()
        guard let index = operations.firstIndex(where: { $0.id == operation.id }) else { return }
        operations[index] = operation
        sortQueue()
        try await persist()
    }

    func readyOperations(at date: Date = Date()) async throws -> [SyncOperation] {
        try await loadIfNeeded()
        return operations
            .filter { $0.nextAttemptAt <= date }
            .sorted { lhs, rhs in
                if lhs.nextAttemptAt != rhs.nextAttemptAt {
                    return lhs.nextAttemptAt < rhs.nextAttemptAt
                }
                return lhs.occurredAt < rhs.occurredAt
            }
    }

    func nextRetryDate() async throws -> Date? {
        try await loadIfNeeded()
        return operations.map(\.nextAttemptAt).min()
    }

    func count() async throws -> Int {
        try await loadIfNeeded()
        return operations.count
    }

    func clear() async throws {
        try await loadIfNeeded()
        operations.removeAll()
        try await persist()
    }

    // MARK: - Private

    private func coalesce(_ incoming: SyncOperation) {
        guard let existingIndex = operations.firstIndex(where: {
            $0.entityType == incoming.entityType && $0.entityID == incoming.entityID
        }) else {
            operations.append(incoming)
            sortQueue()
            return
        }

        let existing = operations[existingIndex]
        let replacement: SyncOperation

        switch (existing.kind, incoming.kind) {
        case (.upsert, .upsert):
            replacement = incoming
        case (.upsert, .delete):
            replacement = incoming
        case (.delete, .upsert):
            replacement = incoming
        case (.delete, .delete):
            replacement = incoming
        }

        operations[existingIndex] = replacement
        sortQueue()
    }

    private func sortQueue() {
        operations.sort { lhs, rhs in
            if lhs.nextAttemptAt != rhs.nextAttemptAt {
                return lhs.nextAttemptAt < rhs.nextAttemptAt
            }
            return lhs.occurredAt < rhs.occurredAt
        }
    }

    private func loadIfNeeded() async throws {
        guard !isLoaded else { return }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            isLoaded = true
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            operations = try JSONDecoder().decode([SyncOperation].self, from: data)
            sortQueue()
            isLoaded = true
        } catch {
            // Corrupted queue shouldn't block the app from operating locally.
            print("[OfflineSyncQueueStore] Queue file corrupted, resetting: \(error)")
            operations = []
            isLoaded = true
        }
    }

    private func persist() async throws {
        let data = try JSONEncoder().encode(operations)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
