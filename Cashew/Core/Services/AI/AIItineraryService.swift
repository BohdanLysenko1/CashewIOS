import Foundation

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
    let userNote: String?
    let vibe: String?
    let pace: String?
}

// MARK: - Response

struct AIItineraryResponse: Decodable {
    let activities: [AIActivity]
}

struct AIActivity: Decodable, Identifiable, Hashable {
    static func == (lhs: AIActivity, rhs: AIActivity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    // Stable per-decode UUID — server response has no IDs.
    let id: String

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

    private enum CodingKeys: String, CodingKey {
        case title, date, startTime, endTime, location, address, notes, category, estimatedCost, latitude, longitude
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        date: String,
        startTime: String?,
        endTime: String?,
        location: String,
        address: String,
        notes: String,
        category: String,
        estimatedCost: Double?,
        latitude: Double?,
        longitude: Double?
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.address = address
        self.notes = notes
        self.category = category
        self.estimatedCost = estimatedCost
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.title = try c.decode(String.self, forKey: .title)
        self.date = try c.decode(String.self, forKey: .date)
        self.startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
        self.endTime = try c.decodeIfPresent(String.self, forKey: .endTime)
        self.location = try c.decode(String.self, forKey: .location)
        self.address = try c.decode(String.self, forKey: .address)
        self.notes = try c.decode(String.self, forKey: .notes)
        self.category = try c.decode(String.self, forKey: .category)
        self.estimatedCost = try c.decodeIfPresent(Double.self, forKey: .estimatedCost)
        self.latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
    }
}

// MARK: - Conversion to Activity

extension AIActivity {
    func toActivity(tripStartDate: Date, tripCurrency: String) -> Activity {
        let actDate = DateFormatting.isoDate.date(from: date) ?? tripStartDate

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
        try await AIServiceClient.invoke(
            "generate-itinerary",
            body: request,
            functionError: AIItineraryError.functionError,
            decodingFailure: AIItineraryError.decodingFailed
        )
    }
}
