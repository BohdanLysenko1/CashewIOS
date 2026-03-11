import Foundation
import SwiftUI

struct Expense: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var amount: Decimal
    var currency: String
    var category: ExpenseCategory
    var date: Date
    var notes: String
    var receiptURL: URL?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        currency: String = "USD",
        category: ExpenseCategory = .other,
        date: Date = Date(),
        notes: String = "",
        receiptURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.date = date
        self.notes = notes
        self.receiptURL = receiptURL
    }
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

    var color: Color {
        switch self {
        case .accommodation: .blue
        case .transportation: .green
        case .food: .orange
        case .activities: .purple
        case .shopping: .pink
        case .entertainment: .red
        case .health: .mint
        case .communication: .cyan
        case .other: .gray
        }
    }
}
