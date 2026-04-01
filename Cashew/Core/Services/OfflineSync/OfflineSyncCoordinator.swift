import Foundation
import Observation

struct OfflineSyncStatusSnapshot: Sendable {
    let isOnline: Bool
    let pendingCount: Int
    let isFlushing: Bool
    let lastSyncError: String?
    let lastSuccessfulSyncAt: Date?
}

@MainActor
protocol OfflineSyncCoordinatorProtocol: AnyObject {
    var isOnline: Bool { get }
    var pendingCount: Int { get }
    var isFlushing: Bool { get }
    var lastSyncError: String? { get }
    var lastSuccessfulSyncAt: Date? { get }
    var statusSnapshot: OfflineSyncStatusSnapshot { get }

    func enqueueUpsert(_ payload: SyncPayload) async
    func enqueueDelete(entityType: SyncEntityType, entityID: UUID) async
    func flushIfPossible() async
    func flushNow() async
    func clearQueue() async
    func addStatusObserver(_ observer: @escaping (OfflineSyncStatusSnapshot) -> Void) -> UUID
    func removeStatusObserver(_ token: UUID)
}

@Observable
@MainActor
final class OfflineSyncCoordinator: OfflineSyncCoordinatorProtocol {

    private let queueStore: OfflineSyncQueueStore
    private let networkMonitor: NetworkMonitorService
    private weak var dataSyncService: DataSyncService?

    private let remoteTripRepo: SupabaseTripRepository
    private let remoteEventRepo: SupabaseEventRepository
    private let remoteTaskRepo: SupabaseDailyTaskRepository
    private let remoteRoutineRepo: SupabaseDailyRoutineRepository

    private let localTripRepo: LocalTripRepository
    private let localEventRepo: LocalEventRepository
    private let localTaskRepo: LocalDailyTaskRepository
    private let localRoutineRepo: LocalDailyRoutineRepository

    private var observerToken: UUID?
    private var retryTask: Task<Void, Never>?
    private var statusObservers: [UUID: (OfflineSyncStatusSnapshot) -> Void] = [:]

    private(set) var isOnline: Bool {
        didSet { notifyStatusObservers() }
    }
    private(set) var pendingCount = 0 {
        didSet { notifyStatusObservers() }
    }
    private(set) var isFlushing = false {
        didSet { notifyStatusObservers() }
    }
    private(set) var lastSyncError: String? {
        didSet { notifyStatusObservers() }
    }
    private(set) var lastSuccessfulSyncAt: Date? {
        didSet { notifyStatusObservers() }
    }

    var statusSnapshot: OfflineSyncStatusSnapshot {
        OfflineSyncStatusSnapshot(
            isOnline: isOnline,
            pendingCount: pendingCount,
            isFlushing: isFlushing,
            lastSyncError: lastSyncError,
            lastSuccessfulSyncAt: lastSuccessfulSyncAt
        )
    }

    init(
        dataSyncService: DataSyncService,
        queueStore: OfflineSyncQueueStore = OfflineSyncQueueStore(),
        networkMonitor: NetworkMonitorService? = nil,
        remoteTripRepo: SupabaseTripRepository,
        remoteEventRepo: SupabaseEventRepository,
        remoteTaskRepo: SupabaseDailyTaskRepository,
        remoteRoutineRepo: SupabaseDailyRoutineRepository,
        localTripRepo: LocalTripRepository,
        localEventRepo: LocalEventRepository,
        localTaskRepo: LocalDailyTaskRepository,
        localRoutineRepo: LocalDailyRoutineRepository
    ) {
        self.dataSyncService = dataSyncService
        self.queueStore = queueStore
        self.networkMonitor = networkMonitor ?? .shared
        self.remoteTripRepo = remoteTripRepo
        self.remoteEventRepo = remoteEventRepo
        self.remoteTaskRepo = remoteTaskRepo
        self.remoteRoutineRepo = remoteRoutineRepo
        self.localTripRepo = localTripRepo
        self.localEventRepo = localEventRepo
        self.localTaskRepo = localTaskRepo
        self.localRoutineRepo = localRoutineRepo
        self.isOnline = self.networkMonitor.isOnline

        observerToken = self.networkMonitor.addObserver { [weak self] online in
            guard let self else { return }
            self.isOnline = online
            if online {
                Task { await self.flushIfPossible() }
            }
        }

        Task {
            await refreshPendingCount()
            await flushIfPossible()
        }
    }

    func enqueueUpsert(_ payload: SyncPayload) async {
        guard dataSyncService?.isEnabled == true else { return }
        do {
            try await queueStore.enqueue(.upsert(payload))
            await refreshPendingCount()
            await flushIfPossible()
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func enqueueDelete(entityType: SyncEntityType, entityID: UUID) async {
        guard dataSyncService?.isEnabled == true else { return }
        do {
            try await queueStore.enqueue(.delete(entityType: entityType, entityID: entityID))
            await refreshPendingCount()
            await flushIfPossible()
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func flushIfPossible() async {
        guard dataSyncService?.isEnabled == true else { return }
        guard isOnline else { return }
        await flushNow()
    }

    func flushNow() async {
        guard !isFlushing else { return }
        guard dataSyncService?.isEnabled == true else { return }
        guard isOnline else { return }

        retryTask?.cancel()
        isFlushing = true
        defer { isFlushing = false }

        while dataSyncService?.isEnabled == true, isOnline {
            let operation: SyncOperation?
            do {
                operation = try await queueStore.readyOperations().first
            } catch {
                lastSyncError = error.localizedDescription
                break
            }

            guard let operation else { break }

            do {
                try await apply(operation)
                try await queueStore.remove(id: operation.id)
                lastSyncError = nil
                lastSuccessfulSyncAt = Date()
            } catch {
                if isDeleteNotFound(error: error, operation: operation) {
                    try? await queueStore.remove(id: operation.id)
                    await refreshPendingCount()
                    continue
                }

                if shouldRetry(error) {
                    var updated = operation
                    updated.retryCount += 1
                    updated.nextAttemptAt = Date().addingTimeInterval(backoffInterval(for: updated.retryCount))
                    try? await queueStore.update(updated)
                    lastSyncError = error.localizedDescription
                    await refreshPendingCount()
                    scheduleRetryIfNeeded()
                    break
                } else {
                    // Non-retryable operation failure: drop the item so the queue can proceed.
                    try? await queueStore.remove(id: operation.id)
                    lastSyncError = error.localizedDescription
                }
            }

            await refreshPendingCount()
        }

        await refreshPendingCount()
        scheduleRetryIfNeeded()
    }

    func clearQueue() async {
        retryTask?.cancel()
        do {
            try await queueStore.clear()
            await refreshPendingCount()
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func addStatusObserver(_ observer: @escaping (OfflineSyncStatusSnapshot) -> Void) -> UUID {
        let token = UUID()
        statusObservers[token] = observer
        observer(statusSnapshot)
        return token
    }

    func removeStatusObserver(_ token: UUID) {
        statusObservers.removeValue(forKey: token)
    }

    // MARK: - Private

    private func refreshPendingCount() async {
        pendingCount = (try? await queueStore.count()) ?? pendingCount
    }

    private func notifyStatusObservers() {
        let snapshot = statusSnapshot
        for observer in statusObservers.values {
            observer(snapshot)
        }
    }

    private func scheduleRetryIfNeeded() {
        retryTask?.cancel()
        guard dataSyncService?.isEnabled == true, isOnline else { return }

        retryTask = Task { [weak self] in
            guard let self else { return }
            guard let nextRetryDate = try? await queueStore.nextRetryDate() else { return }

            let delay = nextRetryDate.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }
            await flushIfPossible()
        }
    }

    private func backoffInterval(for retryCount: Int) -> TimeInterval {
        let cappedRetryCount = min(retryCount, 8)
        let base = min(pow(2, Double(cappedRetryCount)), 300)
        let jitter = Double.random(in: 0...base * 0.35)
        return base + jitter
    }

    private func shouldRetry(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        let message = error.localizedDescription.lowercased()
        let retryableFragments = [
            "network",
            "offline",
            "timed out",
            "timeout",
            "connection",
            "temporarily unavailable",
            "socket",
            "not authenticated",
            "auth",
            "jwt",
            "session"
        ]
        return retryableFragments.contains { message.contains($0) }
    }

    private func isDeleteNotFound(error: Error, operation: SyncOperation) -> Bool {
        guard operation.kind == .delete else { return false }
        let message = error.localizedDescription.lowercased()
        return message.contains("not found") || message.contains("0 rows")
    }

    private func apply(_ operation: SyncOperation) async throws {
        switch operation.kind {
        case .upsert:
            guard let payload = operation.payload else { return }
            switch payload {
            case .trip(let trip):
                if let remote = try? await remoteTripRepo.fetch(by: trip.id),
                   OfflineConflictResolver.shouldPreferRemote(remoteUpdatedAt: remote.updatedAt, localUpdatedAt: trip.updatedAt) {
                    _ = try await localTripRepo.saveFromSync(remote)
                    return
                }
                let synced = try await remoteTripRepo.save(trip)
                _ = try await localTripRepo.saveFromSync(synced)
            case .event(let event):
                if let remote = try? await remoteEventRepo.fetch(by: event.id),
                   OfflineConflictResolver.shouldPreferRemote(remoteUpdatedAt: remote.updatedAt, localUpdatedAt: event.updatedAt) {
                    _ = try await localEventRepo.saveFromSync(remote)
                    return
                }
                let synced = try await remoteEventRepo.save(event)
                _ = try await localEventRepo.saveFromSync(synced)
            case .dailyTask(let task):
                if let remote = try? await remoteTaskRepo.fetch(by: task.id),
                   OfflineConflictResolver.shouldPreferRemote(remoteUpdatedAt: remote.updatedAt, localUpdatedAt: task.updatedAt) {
                    _ = try await localTaskRepo.saveFromSync(remote)
                    return
                }
                let synced = try await remoteTaskRepo.save(task)
                _ = try await localTaskRepo.saveFromSync(synced)
            case .dailyRoutine(let routine):
                if let remote = try? await remoteRoutineRepo.fetch(by: routine.id),
                   OfflineConflictResolver.shouldPreferRemote(remoteUpdatedAt: remote.updatedAt, localUpdatedAt: routine.updatedAt) {
                    _ = try await localRoutineRepo.saveFromSync(remote)
                    return
                }
                let synced = try await remoteRoutineRepo.save(routine)
                _ = try await localRoutineRepo.saveFromSync(synced)
            }

        case .delete:
            switch operation.entityType {
            case .trip:
                if let remote = try? await remoteTripRepo.fetch(by: operation.entityID),
                   OfflineConflictResolver.shouldSkipDelete(deleteOccurredAt: operation.occurredAt, remoteUpdatedAt: remote.updatedAt) {
                    _ = try await localTripRepo.saveFromSync(remote)
                    return
                }
                try await remoteTripRepo.delete(by: operation.entityID)
            case .event:
                if let remote = try? await remoteEventRepo.fetch(by: operation.entityID),
                   OfflineConflictResolver.shouldSkipDelete(deleteOccurredAt: operation.occurredAt, remoteUpdatedAt: remote.updatedAt) {
                    _ = try await localEventRepo.saveFromSync(remote)
                    return
                }
                try await remoteEventRepo.delete(by: operation.entityID)
            case .dailyTask:
                if let remote = try? await remoteTaskRepo.fetch(by: operation.entityID),
                   OfflineConflictResolver.shouldSkipDelete(deleteOccurredAt: operation.occurredAt, remoteUpdatedAt: remote.updatedAt) {
                    _ = try await localTaskRepo.saveFromSync(remote)
                    return
                }
                try await remoteTaskRepo.delete(by: operation.entityID)
            case .dailyRoutine:
                if let remote = try? await remoteRoutineRepo.fetch(by: operation.entityID),
                   OfflineConflictResolver.shouldSkipDelete(deleteOccurredAt: operation.occurredAt, remoteUpdatedAt: remote.updatedAt) {
                    _ = try await localRoutineRepo.saveFromSync(remote)
                    return
                }
                try await remoteRoutineRepo.delete(by: operation.entityID)
            }
        }
    }
}
