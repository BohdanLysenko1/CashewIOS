import Foundation

struct Expense: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var amount: Decimal
    var currency: String
    var category: ExpenseCategory
    var date: Date
    var notes: String
    var receiptURL: URL?

    var status: ExpenseStatus
    var activityID: UUID?
    var calendarEventID: UUID?
    var startTime: Date?
    var endTime: Date?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        currency: String = "USD",
        category: ExpenseCategory = .other,
        date: Date = Date(),
        notes: String = "",
        receiptURL: URL? = nil,
        status: ExpenseStatus = .approved,
        activityID: UUID? = nil,
        calendarEventID: UUID? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.date = date
        self.notes = notes
        self.receiptURL = receiptURL
        self.status = status
        self.activityID = activityID
        self.calendarEventID = calendarEventID
        self.startTime = startTime
        self.endTime = endTime
    }

    enum CodingKeys: String, CodingKey {
        case id, title, amount, currency, category, date, notes, receiptURL
        case status, activityID, calendarEventID, startTime, endTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Decimal.self, forKey: .amount)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        category = try container.decodeIfPresent(ExpenseCategory.self, forKey: .category) ?? .other
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        receiptURL = try container.decodeIfPresent(URL.self, forKey: .receiptURL)
        // Legacy rows have no status — treat as approved so they keep counting toward spend.
        status = try container.decodeIfPresent(ExpenseStatus.self, forKey: .status) ?? .approved
        activityID = try container.decodeIfPresent(UUID.self, forKey: .activityID)
        calendarEventID = try container.decodeIfPresent(UUID.self, forKey: .calendarEventID)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
    }
}

enum ExpenseStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case approved
    case denied
}

enum ExpenseCategory: String, Codable, Sendable, CaseIterable {
    case accommodation
    case transportation
    case food
    case activities
    case shopping
    case entertainment
    case health
    case communication
    case other

    var displayName: String {
        switch self {
        case .accommodation: "Accommodation"
        case .transportation: "Transportation"
        case .food: "Food & Dining"
        case .activities: "Activities"
        case .shopping: "Shopping"
        case .entertainment: "Entertainment"
        case .health: "Health"
        case .communication: "Communication"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .accommodation: "bed.double.fill"
        case .transportation: "car.fill"
        case .food: "fork.knife"
        case .activities: "figure.hiking"
        case .shopping: "bag.fill"
        case .entertainment: "theatermasks.fill"
        case .health: "cross.case.fill"
        case .communication: "phone.fill"
        case .other: "ellipsis.circle.fill"
        }
    }


}
