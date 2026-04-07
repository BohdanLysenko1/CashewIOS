import Foundation

struct Event: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var date: Date
    var endDate: Date?
    var location: String
    var locationLatitude: Double?
    var locationLongitude: Double?
    var address: String
    var notes: String
    var category: EventCategory
    var isAllDay: Bool
    let createdAt: Date
    var updatedAt: Date

    // Priority
    var priority: EventPriority

    // Reminders
    var reminders: [Reminder]

    // Recurrence
    var recurrenceRule: RecurrenceRule?
    var exceptionDates: [Date]
    var timezoneIdentifier: String?
    var isRecurring: Bool { recurrenceRule != nil }

    // Attachments
    var attachments: [Attachment]

    // Links
    var url: URL?

    // Cost
    var cost: Decimal?
    var currency: String

    // Custom category name (used when category == .custom)
    var customCategoryName: String?

    // Associated trip (optional)
    var tripId: UUID?

    // Sharing
    var ownerId: UUID?      // nil for locally-created events
    var ownerName: String?  // populated on shared events
    var heroMode: String?
    var heroColorToken: String?
    var heroPhotoAttachmentId: UUID?

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        endDate: Date? = nil,
        location: String = "",
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        address: String = "",
        notes: String = "",
        category: EventCategory = .general,
        customCategoryName: String? = nil,
        isAllDay: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        priority: EventPriority = .medium,
        reminders: [Reminder] = [],
        recurrenceRule: RecurrenceRule? = nil,
        exceptionDates: [Date] = [],
        timezoneIdentifier: String? = nil,
        attachments: [Attachment] = [],
        url: URL? = nil,
        cost: Decimal? = nil,
        currency: String = "USD",
        tripId: UUID? = nil,
        ownerId: UUID? = nil,
        ownerName: String? = nil,
        heroMode: String? = nil,
        heroColorToken: String? = nil,
        heroPhotoAttachmentId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.location = location
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.address = address
        self.notes = notes
        self.category = category
        self.customCategoryName = customCategoryName
        self.isAllDay = isAllDay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.priority = priority
        self.reminders = reminders
        self.recurrenceRule = recurrenceRule
        self.exceptionDates = exceptionDates
        self.timezoneIdentifier = timezoneIdentifier
        self.attachments = attachments
        self.url = url
        self.cost = cost
        self.currency = currency
        self.tripId = tripId
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.heroMode = heroMode
        self.heroColorToken = heroColorToken
        self.heroPhotoAttachmentId = heroPhotoAttachmentId
    }

    // MARK: - Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case id, title, date, endDate, location, locationLatitude, locationLongitude
        case address, notes, category, customCategoryName
        case isAllDay, createdAt, updatedAt, priority, reminders
        case recurrenceRule, exceptionDates, timezoneIdentifier
        case attachments, url, cost, currency, tripId
        case ownerId, ownerName
        case heroMode, heroColorToken, heroPhotoAttachmentId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        locationLatitude = try container.decodeIfPresent(Double.self, forKey: .locationLatitude)
        locationLongitude = try container.decodeIfPresent(Double.self, forKey: .locationLongitude)
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        // Map legacy "other" raw value to .custom
        let rawCategory = try container.decodeIfPresent(String.self, forKey: .category) ?? "general"
        category = EventCategory(rawValue: rawCategory) ?? (rawCategory == "other" ? .custom : .general)
        customCategoryName = try container.decodeIfPresent(String.self, forKey: .customCategoryName)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        // New fields with defaults
        priority = try container.decodeIfPresent(EventPriority.self, forKey: .priority) ?? .medium
        reminders = try container.decodeIfPresent([Reminder].self, forKey: .reminders) ?? []
        recurrenceRule = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule)
        exceptionDates = try container.decodeIfPresent([Date].self, forKey: .exceptionDates) ?? []
        timezoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timezoneIdentifier)
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        cost = try container.decodeIfPresent(Decimal.self, forKey: .cost)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        tripId = try container.decodeIfPresent(UUID.self, forKey: .tripId)
        ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
        ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName)
        heroMode = try container.decodeIfPresent(String.self, forKey: .heroMode)
        heroColorToken = try container.decodeIfPresent(String.self, forKey: .heroColorToken)
        heroPhotoAttachmentId = try container.decodeIfPresent(UUID.self, forKey: .heroPhotoAttachmentId)
    }

    // MARK: - Computed Properties

    var categoryDisplayName: String {
        category == .custom ? (customCategoryName ?? "Custom") : category.displayName
    }

    var duration: TimeInterval? {
        guard let endDate else { return nil }
        return endDate.timeIntervalSince(date)
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    var isUpcoming: Bool {
        date > Date()
    }

    var isPast: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let endDate {
            return calendar.startOfDay(for: endDate) < today
        }
        return calendar.startOfDay(for: date) < today
    }
}

enum EventPriority: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var icon: String {
        switch self {
        case .low: "arrow.down"
        case .medium: "minus"
        case .high: "arrow.up"
        }
    }

    var colorName: String {
        switch self {
        case .low: "green"
        case .medium: "blue"
        case .high: "red"
        }
    }
}
