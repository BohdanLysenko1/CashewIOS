import Foundation

/// Marks a type as having a last-modified timestamp, used by the sync merge algorithm.
protocol HasUpdatedAt {
    var updatedAt: Date { get }
}

extension Trip:  HasUpdatedAt {}
extension Event: HasUpdatedAt {}
extension DailyTask: HasUpdatedAt {}
extension DailyRoutine: HasUpdatedAt {}
