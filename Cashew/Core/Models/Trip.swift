import Foundation

struct Trip: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var ownerId: UUID?       // nil for locally-created trips
    var ownerName: String?   // populated on shared trips ("Shared by John")
    var name: String
    var destination: String
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var startDate: Date
    var endDate: Date
    var notes: String
    var coverImageURL: URL?
    var status: TripStatus
    let createdAt: Date
    var updatedAt: Date

    // Budget
    var budget: Decimal?
    var currency: String
    var expenses: [Expense]

    // Itinerary
    var activities: [Activity]

    // Packing
    var packingItems: [PackingItem]

    // Checklist
    var checklistItems: [ChecklistItem]

    // Photos
    var attachments: [Attachment]

    // Accommodation & Transport
    var accommodationName: String
    var accommodationAddress: String
    var accommodationCheckIn: Date?
    var accommodationCheckOut: Date?
    var accommodationConfirmation: String
    var transportationType: String
    var transportationDetails: String
    var transportationConfirmation: String

    nonisolated init(
        id: UUID = UUID(),
        ownerId: UUID? = nil,
        ownerName: String? = nil,
        name: String,
        destination: String,
        destinationLatitude: Double? = nil,
        destinationLongitude: Double? = nil,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        coverImageURL: URL? = nil,
        status: TripStatus = .planning,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        budget: Decimal? = nil,
        currency: String = "USD",
        expenses: [Expense] = [],
        activities: [Activity] = [],
        packingItems: [PackingItem] = [],
        checklistItems: [ChecklistItem] = [],
        attachments: [Attachment] = [],
        accommodationName: String = "",
        accommodationAddress: String = "",
        accommodationCheckIn: Date? = nil,
        accommodationCheckOut: Date? = nil,
        accommodationConfirmation: String = "",
        transportationType: String = "",
        transportationDetails: String = "",
        transportationConfirmation: String = ""
    ) {
        self.id = id
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.name = name
        self.destination = destination
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.coverImageURL = coverImageURL
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.budget = budget
        self.currency = currency
        self.expenses = expenses
        self.activities = activities
        self.packingItems = packingItems
        self.checklistItems = checklistItems
        self.attachments = attachments
        self.accommodationName = accommodationName
        self.accommodationAddress = accommodationAddress
        self.accommodationCheckIn = accommodationCheckIn
        self.accommodationCheckOut = accommodationCheckOut
        self.accommodationConfirmation = accommodationConfirmation
        self.transportationType = transportationType
        self.transportationDetails = transportationDetails
        self.transportationConfirmation = transportationConfirmation
    }

    // MARK: - Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case id, name, destination, destinationLatitude, destinationLongitude
        case startDate, endDate, notes, coverImageURL, status
        case createdAt, updatedAt, budget, currency, expenses, activities
        case packingItems, checklistItems, attachments
        case accommodationName, accommodationAddress, accommodationCheckIn
        case accommodationCheckOut, accommodationConfirmation
        case transportationType, transportationDetails, transportationConfirmation
        case ownerId, ownerName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
        ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName)
        name = try container.decode(String.self, forKey: .name)
        destination = try container.decode(String.self, forKey: .destination)
        destinationLatitude = try container.decodeIfPresent(Double.self, forKey: .destinationLatitude)
        destinationLongitude = try container.decodeIfPresent(Double.self, forKey: .destinationLongitude)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        coverImageURL = try container.decodeIfPresent(URL.self, forKey: .coverImageURL)
        status = try container.decodeIfPresent(TripStatus.self, forKey: .status) ?? .planning
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        // New fields with defaults
        budget = try container.decodeIfPresent(Decimal.self, forKey: .budget)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        expenses = try container.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        activities = try container.decodeIfPresent([Activity].self, forKey: .activities) ?? []
        packingItems = try container.decodeIfPresent([PackingItem].self, forKey: .packingItems) ?? []
        checklistItems = try container.decodeIfPresent([ChecklistItem].self, forKey: .checklistItems) ?? []
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        accommodationName = try container.decodeIfPresent(String.self, forKey: .accommodationName) ?? ""
        accommodationAddress = try container.decodeIfPresent(String.self, forKey: .accommodationAddress) ?? ""
        accommodationCheckIn = try container.decodeIfPresent(Date.self, forKey: .accommodationCheckIn)
        accommodationCheckOut = try container.decodeIfPresent(Date.self, forKey: .accommodationCheckOut)
        accommodationConfirmation = try container.decodeIfPresent(String.self, forKey: .accommodationConfirmation) ?? ""
        transportationType = try container.decodeIfPresent(String.self, forKey: .transportationType) ?? ""
        transportationDetails = try container.decodeIfPresent(String.self, forKey: .transportationDetails) ?? ""
        transportationConfirmation = try container.decodeIfPresent(String.self, forKey: .transportationConfirmation) ?? ""
    }

    // MARK: - Computed Properties

    var totalExpenses: Decimal {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var remainingBudget: Decimal? {
        guard let budget else { return nil }
        return budget - totalExpenses
    }

    var budgetProgress: Double? {
        guard let budget, budget > 0 else { return nil }
        return Double(truncating: (totalExpenses / budget) as NSNumber)
    }

    var packingProgress: Double {
        guard !packingItems.isEmpty else { return 0 }
        let packed = packingItems.filter { $0.isPacked }.count
        return Double(packed) / Double(packingItems.count)
    }

    var checklistProgress: Double {
        guard !checklistItems.isEmpty else { return 0 }
        let completed = checklistItems.filter { $0.isCompleted }.count
        return Double(completed) / Double(checklistItems.count)
    }

    var computedStatus: TripStatus {
        if status == .cancelled { return .cancelled }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        if end < today {
            return .completed
        } else if start <= today && end >= today {
            return .active
        } else {
            return .upcoming
        }
    }

    var daysUntilTrip: Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: startDate)
        return calendar.dateComponents([.day], from: today, to: start).day
    }

    var tripDuration: Int {
        let calendar = Calendar.current
        return (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
    }

    func activitiesForDate(_ date: Date) -> [Activity] {
        let calendar = Calendar.current
        return activities.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { ($0.startTime ?? $0.date) < ($1.startTime ?? $1.date) }
    }
}
