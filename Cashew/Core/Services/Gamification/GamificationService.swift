import Foundation
import Observation

@Observable
@MainActor
final class GamificationService {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let totalXP = "gam_totalXP"
    }

    // MARK: - Level Table

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

    private(set) var totalXP: Int {
        didSet { UserDefaults.standard.set(totalXP, forKey: Keys.totalXP) }
    }

    /// Set by `award(xp:)` when a level boundary is crossed. Cleared by the UI after showing the banner.
    var pendingLevelUp: Int? = nil

    // MARK: - Init

    init() {
        self.totalXP = UserDefaults.standard.integer(forKey: Keys.totalXP)
    }

    // MARK: - Computed

    var currentLevel: Int {
        var result = 1
        for entry in Self.levels where totalXP >= entry.xpRequired {
            result = entry.level
        }
        return result
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

    // MARK: - Award / Deduct

    /// Call when a task is marked complete. Pass the current best streak length for the multiplier.
    func award(xp: Int, streakDays: Int = 0) {
        let levelBefore = currentLevel
        totalXP += adjusted(xp: xp, streakDays: streakDays)
        let levelAfter = currentLevel
        if levelAfter > levelBefore {
            pendingLevelUp = levelAfter
        }
    }

    /// Call when a completed task is toggled back to incomplete.
    func deduct(xp: Int, streakDays: Int = 0) {
        totalXP = max(0, totalXP - adjusted(xp: xp, streakDays: streakDays))
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
}
