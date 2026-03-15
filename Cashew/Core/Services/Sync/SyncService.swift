import Foundation
import Observation

@Observable
@MainActor
final class SyncService: SyncServiceProtocol {

    private let localTripRepository: TripRepositoryProtocol
    private let localEventRepository: EventRepositoryProtocol
    private let cloudTripRepository: TripRepositoryProtocol
    private let cloudEventRepository: EventRepositoryProtocol
    private let cloudKit: CloudKitManager

    private var syncTask: Task<Void, Never>?

    var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: UserDefaultsKeys.isSyncEnabled)
            if isSyncEnabled {
                triggerSync()
            } else {
                syncTask?.cancel()
                syncTask = nil
            }
        }
    }

    private(set) var syncStatus: SyncStatus = .idle
    private(set) var lastSyncDate: Date?

    init(
        localTripRepository: TripRepositoryProtocol,
        localEventRepository: EventRepositoryProtocol,
        cloudTripRepository: TripRepositoryProtocol? = nil,
        cloudEventRepository: EventRepositoryProtocol? = nil,
        cloudKit: CloudKitManager = .shared
    ) {
        self.localTripRepository = localTripRepository
        self.localEventRepository = localEventRepository
        self.cloudTripRepository = cloudTripRepository ?? CloudTripRepository(cloudKit: cloudKit)
        self.cloudEventRepository = cloudEventRepository ?? CloudEventRepository(cloudKit: cloudKit)
        self.cloudKit = cloudKit
        self.isSyncEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.isSyncEnabled)
    }

    func checkCloudAvailability() async -> Bool {
        do {
            return try await cloudKit.checkAccountStatus()
        } catch {
            print("[SyncService] Could not check iCloud availability: \(error)")
            return false
        }
    }

    func sync() async {
        guard isSyncEnabled else { return }

        syncStatus = .syncing

        do {
            try await syncTrips()
            try await syncEvents()

            lastSyncDate = Date()
            syncStatus = .success
        } catch {
            if Task.isCancelled {
                syncStatus = .idle
            } else {
                syncStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func triggerSync() {
        syncTask?.cancel()
        syncTask = Task {
            await sync()
        }
    }

    private func syncTrips() async throws {
        try Task.checkCancellation()
        let local = try await localTripRepository.fetchAll()
        let cloud = try await cloudTripRepository.fetchAll()
        try await mergeSync(
            local: local, cloud: cloud,
            saveToCloud: { try await cloudTripRepository.save($0) },
            saveToLocal: { try await localTripRepository.save($0) }
        )
    }

    private func syncEvents() async throws {
        try Task.checkCancellation()
        let local = try await localEventRepository.fetchAll()
        let cloud = try await cloudEventRepository.fetchAll()
        try await mergeSync(
            local: local, cloud: cloud,
            saveToCloud: { try await cloudEventRepository.save($0) },
            saveToLocal: { try await localEventRepository.save($0) }
        )
    }

    /// Generic three-way merge: items present only locally are pushed to cloud,
    /// items present only in cloud are pulled locally, conflicts resolve by latest `updatedAt`.
    private func mergeSync<T: Identifiable>(
        local: [T], cloud: [T],
        saveToCloud: (T) async throws -> Void,
        saveToLocal: (T) async throws -> Void
    ) async throws where T.ID == UUID, T: HasUpdatedAt {
        let localDict  = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let cloudDict  = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        let allIDs     = Set(localDict.keys).union(cloudDict.keys)

        for id in allIDs {
            try Task.checkCancellation()
            switch (localDict[id], cloudDict[id]) {
            case let (l?, c?) where l.updatedAt > c.updatedAt: try await saveToCloud(l)
            case let (l?, c?) where c.updatedAt > l.updatedAt: try await saveToLocal(c)
            case let (l?, nil):                                try await saveToCloud(l)
            case let (nil, c?):                                try await saveToLocal(c)
            default: break
            }
        }
    }
}
