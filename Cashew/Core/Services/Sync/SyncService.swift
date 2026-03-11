import Foundation
import Observation

@Observable
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

        let localTrips = try await localTripRepository.fetchAll()
        let cloudTrips = try await cloudTripRepository.fetchAll()

        let localDict = Dictionary(uniqueKeysWithValues: localTrips.map { ($0.id, $0) })
        let cloudDict = Dictionary(uniqueKeysWithValues: cloudTrips.map { ($0.id, $0) })

        let allIDs = Set(localDict.keys).union(cloudDict.keys)

        for id in allIDs {
            try Task.checkCancellation()

            let local = localDict[id]
            let cloud = cloudDict[id]

            switch (local, cloud) {
            case let (local?, cloud?):
                if local.updatedAt > cloud.updatedAt {
                    try await cloudTripRepository.save(local)
                } else if cloud.updatedAt > local.updatedAt {
                    try await localTripRepository.save(cloud)
                }

            case let (local?, nil):
                try await cloudTripRepository.save(local)

            case let (nil, cloud?):
                try await localTripRepository.save(cloud)

            case (nil, nil):
                break
            }
        }
    }

    private func syncEvents() async throws {
        try Task.checkCancellation()

        let localEvents = try await localEventRepository.fetchAll()
        let cloudEvents = try await cloudEventRepository.fetchAll()

        let localDict = Dictionary(uniqueKeysWithValues: localEvents.map { ($0.id, $0) })
        let cloudDict = Dictionary(uniqueKeysWithValues: cloudEvents.map { ($0.id, $0) })

        let allIDs = Set(localDict.keys).union(cloudDict.keys)

        for id in allIDs {
            try Task.checkCancellation()

            let local = localDict[id]
            let cloud = cloudDict[id]

            switch (local, cloud) {
            case let (local?, cloud?):
                if local.updatedAt > cloud.updatedAt {
                    try await cloudEventRepository.save(local)
                } else if cloud.updatedAt > local.updatedAt {
                    try await localEventRepository.save(cloud)
                }

            case let (local?, nil):
                try await cloudEventRepository.save(local)

            case let (nil, cloud?):
                try await localEventRepository.save(cloud)

            case (nil, nil):
                break
            }
        }
    }
}
