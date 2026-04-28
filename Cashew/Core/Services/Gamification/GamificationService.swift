import Foundation
import Observation
import Supabase

// MARK: - GamificationServiceProtocol

@MainActor
protocol GamificationServiceProtocol: AnyObject {
    var totalXP: Int { get }
    var currentLevel: Int { get }
    var levelTitle: String { get }
    var levelProgress: Double { get }
    var xpToNextLevel: Int { get }
    var isMaxLevel: Bool { get }
    var pendingLevelUp: Int? { get set }

    func refreshForCurrentUser() async
    func award(xp: Int, streakDays: Int)
    func deduct(xp: Int, streakDays: Int)
    func clearLevelUp()
}

protocol GamificationCloudStore {
    func fetchState(for userId: UUID) async throws -> GamificationCloudState
    func upsertState(for userId: UUID, totalXP: Int, updatedAt: Date) async throws
}

struct GamificationCloudState: Equatable, Sendable {
    let totalXP: Int
    let updatedAt: Date
}

final class SupabaseGamificationCloudStore: GamificationCloudStore {

    private let client = SupabaseManager.client

    func fetchState(for userId: UUID) async throws -> GamificationCloudState {
        let response: UserGamificationDTO = try await client
            .from(SupabaseSchema.Table.users)
            .select(SupabaseSchema.Select.userGamification)
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return GamificationCloudState(
            totalXP: max(0, response.totalXP),
            updatedAt: response.xpUpdatedAt ?? Date.distantPast
        )
    }

    func upsertState(for userId: UUID, totalXP: Int, updatedAt: Date) async throws {
        try await client
            .from(SupabaseSchema.Table.users)
            .update(UserGamificationUpdatePayload(totalXP: max(0, totalXP), xpUpdatedAt: updatedAt))
            .eq("id", value: userId.uuidString)
            .execute()
    }
}

private struct UserGamificationDTO: Decodable {
    let totalXP: Int
    let xpUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case totalXP = "total_xp"
        case xpUpdatedAt = "xp_updated_at"
    }
}

private struct UserGamificationUpdatePayload: Encodable {
    let totalXP: Int
    let xpUpdatedAt: Date

    enum CodingKeys: String, CodingKey {
        case totalXP = "total_xp"
        case xpUpdatedAt = "xp_updated_at"
    }
}

@Observable
@MainActor
final class GamificationService: GamificationServiceProtocol {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let legacyTotalXP = "gam_totalXP"
        static let legacyXPUpdatedAt = "gam_totalXP_updated_at"
        static let userTotalXPPrefix = "gam_totalXP_"
        static let userXPUpdatedAtPrefix = "gam_totalXP_updated_at_"
    }

    // MARK: - Level Table

    /// App-wide reference data accessed without a service instance.
    /// Intentionally omitted from `GamificationServiceProtocol` since callers (UI rows,
    /// notification scheduler) only need read-only metadata, not a fully wired service.
    static let levels: [(level: Int, title: String, xpRequired: Int)] = [
        (1,  "Starter",     0),
        (2,  "Planner",     150),
        (3,  "Builder",     400),
        (4,  "Focused",     800),
        (5,  "Achiever",    1_500),
        (6,  "Disciplined", 2_500),
        (7,  "Expert",      4_000),
        (8,  "Momentum",    6_000),
        (9,  "Elite",       9_000),
        (10, "Legend",      13_000),
    ]

    // MARK: - State

    private(set) var totalXP: Int

    /// Set by `award(xp:)` when a level boundary is crossed. Cleared by the UI after showing the banner.
    var pendingLevelUp: Int? = nil

    private let authService: (any AuthServiceProtocol)?
    private let dataSyncService: DataSyncService?
    private let cloudStore: (any GamificationCloudStore)?
    private let userDefaults: UserDefaults
    private let nowProvider: () -> Date

    private var activeUserId: UUID?
    private var cloudSyncTask: Task<Void, Never>?

    // MARK: - Init

    init(
        authService: (any AuthServiceProtocol)? = nil,
        dataSyncService: DataSyncService? = nil,
        cloudStore: (any GamificationCloudStore)? = nil,
        userDefaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.authService = authService
        self.dataSyncService = dataSyncService
        self.cloudStore = cloudStore ?? SupabaseGamificationCloudStore()
        self.userDefaults = userDefaults
        self.nowProvider = nowProvider
        self.totalXP = max(0, userDefaults.integer(forKey: Keys.legacyTotalXP))
    }

    // MARK: - Computed

    var currentLevel: Int {
        Self.level(for: totalXP)
    }

    var levelTitle: String {
        Self.levels.first { $0.level == currentLevel }?.title ?? "Starter"
    }

    /// XP at the start of the current level.
    var xpForCurrentLevel: Int {
        Self.levels.first { $0.level == currentLevel }?.xpRequired ?? 0
    }

    /// XP needed to reach the next level, or nil if at max.
    var xpForNextLevel: Int? {
        Self.levels.first { $0.level == currentLevel + 1 }?.xpRequired
    }

    /// 0.0 – 1.0 progress within the current level band.
    var levelProgress: Double {
        guard let nextXP = xpForNextLevel else { return 1.0 }
        let band = nextXP - xpForCurrentLevel
        let earned = totalXP - xpForCurrentLevel
        guard band > 0 else { return 1.0 }
        return min(1.0, Double(earned) / Double(band))
    }

    /// How many more XP until the next level.
    var xpToNextLevel: Int {
        guard let nextXP = xpForNextLevel else { return 0 }
        return max(0, nextXP - totalXP)
    }

    var isMaxLevel: Bool { currentLevel >= Self.levels.count }

    // MARK: - User Context

    func refreshForCurrentUser() async {
        let newActiveUserId = authService?.currentUser?.id
        if activeUserId != newActiveUserId {
            pendingLevelUp = nil
            cloudSyncTask?.cancel()
            cloudSyncTask = nil
        }
        activeUserId = newActiveUserId

        guard let user = authService?.currentUser else {
            totalXP = max(0, userDefaults.integer(forKey: Keys.legacyTotalXP))
            return
        }

        loadLocalXP(for: user)
        await reconcileCloudState(for: user)
    }

    // MARK: - Award / Deduct

    /// Call when a task is marked complete. Pass the current best streak length for the multiplier.
    func award(xp: Int, streakDays: Int = 0) {
        let levelBefore = currentLevel
        totalXP = max(0, totalXP + adjusted(xp: xp, streakDays: streakDays))
        persistLocalXP(updatedAt: nowProvider())
        scheduleCloudSync()
        let levelAfter = currentLevel
        if levelAfter > levelBefore {
            pendingLevelUp = levelAfter
        }
    }

    /// Call when a completed task is toggled back to incomplete.
    func deduct(xp: Int, streakDays: Int = 0) {
        totalXP = max(0, totalXP - adjusted(xp: xp, streakDays: streakDays))
        persistLocalXP(updatedAt: nowProvider())
        scheduleCloudSync()
    }

    func clearLevelUp() {
        pendingLevelUp = nil
    }

    // MARK: - Streak Multiplier

    /// Returns the XP value after applying the streak multiplier.
    private func adjusted(xp: Int, streakDays: Int) -> Int {
        let multiplier: Double
        switch streakDays {
        case 14...: multiplier = 2.0
        case 7...:  multiplier = 1.5
        default:    multiplier = 1.0
        }
        return Int(Double(xp) * multiplier)
    }

    // MARK: - Level Helpers

    static func level(for totalXP: Int) -> Int {
        var result = 1
        for entry in Self.levels where totalXP >= entry.xpRequired {
            result = entry.level
        }
        return result
    }

    // MARK: - Local Persistence

    private func loadLocalXP(for user: AppUser) {
        let totalXPKey = userTotalXPKey(for: user.id)
        let userScopedXP = (userDefaults.object(forKey: totalXPKey) as? Int).map { max(0, $0) }

        let resolvedXP: Int
        let seedUpdatedAt: Date
        if let userScopedXP {
            resolvedXP = userScopedXP
            seedUpdatedAt = nowProvider()
        } else {
            let legacyXP = max(0, userDefaults.integer(forKey: Keys.legacyTotalXP))
            resolvedXP = max(legacyXP, user.totalXP)
            let seededFromLegacy = legacyXP > user.totalXP
            seedUpdatedAt = seededFromLegacy ? nowProvider() : (user.xpUpdatedAt ?? user.createdAt)
        }

        totalXP = resolvedXP
        userDefaults.set(resolvedXP, forKey: totalXPKey)

        let xpUpdatedAtKey = userXPUpdatedAtKey(for: user.id)
        if userDefaults.object(forKey: xpUpdatedAtKey) == nil {
            userDefaults.set(seedUpdatedAt.timeIntervalSince1970, forKey: xpUpdatedAtKey)
        }
    }

    private func persistLocalXP(updatedAt: Date) {
        if let userId = activeUserId {
            userDefaults.set(max(0, totalXP), forKey: userTotalXPKey(for: userId))
            userDefaults.set(updatedAt.timeIntervalSince1970, forKey: userXPUpdatedAtKey(for: userId))
        } else {
            userDefaults.set(max(0, totalXP), forKey: Keys.legacyTotalXP)
            userDefaults.set(updatedAt.timeIntervalSince1970, forKey: Keys.legacyXPUpdatedAt)
        }
    }

    private func localXPUpdatedAt(for userId: UUID) -> Date {
        if let epoch = userDefaults.object(forKey: userXPUpdatedAtKey(for: userId)) as? TimeInterval {
            return Date(timeIntervalSince1970: epoch)
        }
        return Date.distantPast
    }

    private func userTotalXPKey(for userId: UUID) -> String {
        Keys.userTotalXPPrefix + userId.uuidString.lowercased()
    }

    private func userXPUpdatedAtKey(for userId: UUID) -> String {
        Keys.userXPUpdatedAtPrefix + userId.uuidString.lowercased()
    }

    // MARK: - Cloud Sync

    private func scheduleCloudSync() {
        guard shouldSyncToCloud, let userId = activeUserId else { return }

        let snapshotXP = totalXP
        let snapshotUpdatedAt = localXPUpdatedAt(for: userId)
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            await self?.pushCloudState(userId: userId, totalXP: snapshotXP, updatedAt: snapshotUpdatedAt)
        }
    }

    private func reconcileCloudState(for user: AppUser) async {
        guard shouldSyncToCloud, let cloudStore else { return }

        let localUpdatedAt = localXPUpdatedAt(for: user.id)
        do {
            let remote = try await cloudStore.fetchState(for: user.id)
            if remote.updatedAt > localUpdatedAt {
                totalXP = max(0, remote.totalXP)
                persistLocalXP(updatedAt: remote.updatedAt)
            } else if localUpdatedAt > remote.updatedAt || totalXP != remote.totalXP {
                try await cloudStore.upsertState(
                    for: user.id,
                    totalXP: max(0, totalXP),
                    updatedAt: localUpdatedAt
                )
            }
        } catch {
            print("[GamificationService] Cloud reconcile failed: \(error)")
        }
    }

    private func pushCloudState(userId: UUID, totalXP: Int, updatedAt: Date) async {
        guard shouldSyncToCloud, let cloudStore else { return }
        do {
            try await cloudStore.upsertState(
                for: userId,
                totalXP: max(0, totalXP),
                updatedAt: updatedAt
            )
        } catch {
            print("[GamificationService] Failed to persist XP to cloud: \(error)")
        }
    }

    private var shouldSyncToCloud: Bool {
        guard authService?.isAuthenticated == true else { return false }
        guard dataSyncService?.isEnabled ?? true else { return false }
        return cloudStore != nil
    }
}
