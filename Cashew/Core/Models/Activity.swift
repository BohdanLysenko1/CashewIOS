import Foundation

struct Activity: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var location: String
    var address: String
    var notes: String
    var category: ActivityCategory
    var cost: Decimal?
    var currency: String
    var isBooked: Bool
    var confirmationNumber: String
    var link: URL?
    var latitude: Double?
    var longitude: Double?
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        startTime: Date? = nil,
        endTime: Date? = nil,
        location: String = "",
        address: String = "",
        notes: String = "",
        category: ActivityCategory = .activity,
        cost: Decimal? = nil,
        currency: String = "USD",
        isBooked: Bool = false,
        confirmationNumber: String = "",
        link: URL? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        sortOrder: Int = 0
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
        self.cost = cost
        self.currency = currency
        self.isBooked = isBooked
        self.confirmationNumber = confirmationNumber
        self.link = link
        self.latitude = latitude
        self.longitude = longitude
        self.sortOrder = sortOrder
    }

    enum CodingKeys: String, CodingKey {
        case id, title, date, startTime, endTime, location, address
        case notes, category, cost, currency, isBooked, confirmationNumber
        case link, latitude, longitude, sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        location = try container.decode(String.self, forKey: .location)
        address = try container.decode(String.self, forKey: .address)
        notes = try container.decode(String.self, forKey: .notes)
        category = try container.decode(ActivityCategory.self, forKey: .category)
        cost = try container.decodeIfPresent(Decimal.self, forKey: .cost)
        currency = try container.decode(String.self, forKey: .currency)
        isBooked = try container.decode(Bool.self, forKey: .isBooked)
        confirmationNumber = try container.decode(String.self, forKey: .confirmationNumber)
        link = try container.decodeIfPresent(URL.self, forKey: .link)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

enum ActivityCategory: String, Codable, Sendable, CaseIterable {
    case flight
    case train
    case bus
    case car
    case ferry
    case hotel
    case restaurant
    case museum
    case tour
    case beach
    case hiking
    case shopping
    case nightlife
    case activity
    case other

    var displayName: String {
        switch self {
        case .flight: "Flight"
        case .train: "Train"
        case .bus: "Bus"
        case .car: "Car Rental"
        case .ferry: "Ferry"
        case .hotel: "Hotel"
        case .restaurant: "Restaurant"
        case .museum: "Museum"
        case .tour: "Tour"
        case .beach: "Beach"
        case .hiking: "Hiking"
        case .shopping: "Shopping"
        case .nightlife: "Nightlife"
        case .activity: "Activity"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .flight: "airplane"
        case .train: "tram.fill"
        case .bus: "bus.fill"
        case .car: "car.fill"
        case .ferry: "ferry.fill"
        case .hotel: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .museum: "building.columns.fill"
        case .tour: "figure.walk"
        case .beach: "beach.umbrella.fill"
        case .hiking: "figure.hiking"
        case .shopping: "bag.fill"
        case .nightlife: "moon.stars.fill"
        case .activity: "star.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var isTransportation: Bool {
        switch self {
        case .flight, .train, .bus, .car, .ferry:
            return true
        default:
            return false
        }
    }
}
