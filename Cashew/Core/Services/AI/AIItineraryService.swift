import Foundation
import Supabase

// MARK: - Request

struct AIItineraryRequest: Encodable {
    let destination: String
    let destinationLatitude: Double?
    let destinationLongitude: Double?
    let startDate: String
    let endDate: String
    let tripCurrency: String
    let budgetAllocation: Double
    let interests: [String]
    let existingActivityTitles: [String]
    var targetDate: String?  // When set, regenerate only this day
}

// MARK: - Response

struct AIItineraryResponse: Decodable {
    let activities: [AIActivity]
}

struct AIActivity: Decodable, Identifiable, Hashable {
    static func == (lhs: AIActivity, rhs: AIActivity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    // Composite key — Gemini returns no IDs
    var id: String { "\(date)-\(title)-\(startTime ?? "")" }

    let title: String
    let date: String        // "YYYY-MM-DD"
    let startTime: String?  // "HH:MM"
    let endTime: String?    // "HH:MM"
    let location: String
    let address: String
    let notes: String
    let category: String    // matches ActivityCategory raw value
    let estimatedCost: Double?
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Conversion to Activity

extension AIActivity {
    func toActivity(tripStartDate: Date, tripCurrency: String) -> Activity {
        let isoFmt = DateFormatter()
        isoFmt.dateFormat = "yyyy-MM-dd"
        let actDate = isoFmt.date(from: date) ?? tripStartDate

        func parseTime(_ t: String) -> Date? {
            let parts = t.split(separator: ":").compactMap { Int($0) }
            guard parts.count >= 2 else { return nil }
            return Calendar.current.date(
                bySettingHour: parts[0],
                minute: parts[1],
                second: 0,
                of: actDate
            )
        }

        return Activity(
            title: title,
            date: actDate,
            startTime: startTime.flatMap(parseTime),
            endTime: endTime.flatMap(parseTime),
            location: location,
            address: address,
            notes: notes,
            category: ActivityCategory(rawValue: category) ?? .activity,
            cost: estimatedCost.map { Decimal($0) },
            currency: tripCurrency,
            latitude: latitude,
            longitude: longitude
        )
    }
}

// MARK: - Error

enum AIItineraryError: LocalizedError {
    case functionError(String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .functionError(let m): return "AI generation failed: \(m)"
        case .decodingFailed(let e): return "Failed to parse AI response: \(e.localizedDescription)"
        }
    }
}

// MARK: - Protocol

protocol AIItineraryServiceProtocol {
    func generateItinerary(request: AIItineraryRequest) async throws -> AIItineraryResponse
}

// MARK: - Implementation

final class AIItineraryService: AIItineraryServiceProtocol {
    func generateItinerary(request: AIItineraryRequest) async throws -> AIItineraryResponse {
        do {
            let response: AIItineraryResponse = try await SupabaseManager.client.functions.invoke(
                "generate-itinerary",
                options: .init(body: request)
            )
            return response
        } catch let fnError as FunctionsError {
            // Extract the real error message from the response body
            if case .httpError(_, let body) = fnError,
               let envelope = try? JSONDecoder().decode([String: String].self, from: body),
               let message = envelope["error"] {
                throw AIItineraryError.functionError(message)
            }
            throw AIItineraryError.functionError(fnError.localizedDescription)
        } catch {
            throw AIItineraryError.decodingFailed(error)
        }
    }
}
