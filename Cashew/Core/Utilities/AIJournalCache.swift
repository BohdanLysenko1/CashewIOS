import Foundation
import CryptoKit

/// Domain-specific facade over `AICache` for trip-summary journal responses.
/// Defines the cache key shape and the content-hash function used to invalidate
/// stale entries when trip content changes.
enum AIJournalCache {

    private static let cache = AICache<AITripSummaryResponse>(prefix: "ai_journal_v1_")

    static func load(tripId: UUID, tone: AITripSummaryTone, contentHash: String) -> AITripSummaryResponse? {
        cache.load(key: cacheKey(tripId: tripId, tone: tone, contentHash: contentHash))
    }

    static func save(_ response: AITripSummaryResponse, tripId: UUID, tone: AITripSummaryTone, contentHash: String) {
        cache.save(response, key: cacheKey(tripId: tripId, tone: tone, contentHash: contentHash))
    }

    /// Short hex digest over the trip content that should invalidate cached journals.
    /// Callers should pass activities.count, expenses.count, trip.updatedAt, and notes.
    static func contentHash(
        activityCount: Int,
        expenseCount: Int,
        updatedAt: Date,
        notes: String,
        accommodationName: String,
        accommodationAddress: String,
        transportationType: String,
        transportationDetails: String
    ) -> String {
        let canonical = [
            "\(activityCount)",
            "\(expenseCount)",
            "\(updatedAt.timeIntervalSince1970)",
            notes,
            accommodationName,
            accommodationAddress,
            transportationType,
            transportationDetails,
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(12).lowercased()
    }

    // MARK: - Private

    private static func cacheKey(tripId: UUID, tone: AITripSummaryTone, contentHash: String) -> String {
        "\(tripId.uuidString)_\(tone.rawValue)_\(contentHash)"
    }
}
