import Foundation

// MARK: - Request / Response DTOs

struct AIPackingListRequest: Encodable {
    let destination: String
    let tripDurationDays: Int
    let activities: [String]
    let interests: [String]
    let weatherSummary: String?
    let travelerCount: Int
    let preferences: [String]
}

struct AIPackingListResponse: Decodable {
    let categories: [AIPackingCategory]
}

struct AIPackingCategory: Decodable, Identifiable {
    var id: String { category }
    let category: String
    let items: [AIPackingItem]
}

struct AIPackingItem: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let quantity: Int
    let essential: Bool
}

// MARK: - Conversion

extension AIPackingCategory {
    func toPackingItems() -> [PackingItem] {
        let cat = PackingCategory(rawValue: category) ?? .other
        return items.map { item in
            PackingItem(
                name: item.name,
                quantity: item.quantity,
                isPacked: false,
                category: cat
            )
        }
    }
}

// MARK: - Protocol

protocol AIPackingListServiceProtocol {
    func generatePackingList(request: AIPackingListRequest) async throws -> AIPackingListResponse
}

// MARK: - Errors

enum AIPackingListError: LocalizedError {
    case functionError(String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .functionError(let msg): return msg
        case .decodingFailed(let err): return "Failed to decode packing list: \(err.localizedDescription)"
        }
    }
}

// MARK: - Implementation

final class AIPackingListService: AIPackingListServiceProtocol {

    func generatePackingList(request: AIPackingListRequest) async throws -> AIPackingListResponse {
        try await AIServiceClient.invoke(
            "generate-packing-list",
            body: request,
            functionError: AIPackingListError.functionError,
            decodingFailure: AIPackingListError.decodingFailed
        )
    }
}
