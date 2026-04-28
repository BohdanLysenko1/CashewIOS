import Foundation

// MARK: - Tone

enum AITripSummaryTone: String, Codable, CaseIterable, Identifiable, Sendable {
    case warm
    case poetic
    case playful
    case concise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warm: "Warm"
        case .poetic: "Poetic"
        case .playful: "Playful"
        case .concise: "Concise"
        }
    }

    var icon: String {
        switch self {
        case .warm: "heart.fill"
        case .poetic: "sparkles"
        case .playful: "face.smiling.fill"
        case .concise: "scissors"
        }
    }
}

// MARK: - Request / Response DTOs

struct AITripSummaryRequest: Encodable {
    let tripName: String
    let destination: String
    let startDate: String
    let endDate: String
    let currency: String
    let totalBudget: Double?
    let totalSpent: Double?
    let tone: String
    let notes: String?
    let accommodationName: String?
    let accommodationAddress: String?
    let transportationType: String?
    let transportationDetails: String?
    let activities: [AITripSummaryActivity]
    let expenses: [AITripSummaryExpense]
}

struct AITripSummaryActivity: Encodable {
    let title: String
    let date: String
    let category: String
    let estimatedCost: Double?
    let location: String?
    let address: String?
    let startTime: String?
    let endTime: String?
    let notes: String?
}

struct AITripSummaryExpense: Encodable {
    let title: String
    let amount: Double
    let category: String
    let date: String?
    let notes: String?
}

struct AITripSummaryResponse: Codable {
    let overview: String
    let highlights: [String]
    let dailyRecap: [AIDailyRecap]
    let budgetRecap: AIBudgetRecap
    let funFacts: [String]
}

struct AIDailyRecap: Codable, Identifiable {
    var id: String { date }
    let date: String
    let summary: String
}

struct AIBudgetRecap: Codable {
    let totalBudget: Double?
    let totalSpent: Double?
    let currency: String
    let verdict: String
}

// MARK: - Protocol

protocol AITripSummaryServiceProtocol {
    func generateSummary(request: AITripSummaryRequest) async throws -> AITripSummaryResponse
}

// MARK: - Errors

enum AITripSummaryError: LocalizedError {
    case functionError(String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .functionError(let msg): return msg
        case .decodingFailed(let err): return "Failed to decode trip summary: \(err.localizedDescription)"
        }
    }
}

// MARK: - Implementation

final class AITripSummaryService: AITripSummaryServiceProtocol {

    func generateSummary(request: AITripSummaryRequest) async throws -> AITripSummaryResponse {
        try await AIServiceClient.invoke(
            "generate-trip-summary",
            body: request,
            functionError: AITripSummaryError.functionError,
            decodingFailure: AITripSummaryError.decodingFailed
        )
    }
}
