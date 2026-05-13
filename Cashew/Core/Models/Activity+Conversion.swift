import Foundation

extension ActivityCategory {
    var asExpenseCategory: ExpenseCategory {
        switch self {
        case .flight, .train, .bus, .car, .ferry: return .transportation
        case .hotel: return .accommodation
        case .restaurant: return .food
        case .museum, .tour, .beach, .hiking, .activity: return .activities
        case .shopping: return .shopping
        case .nightlife: return .entertainment
        case .other: return .other
        }
    }

    var asEventCategory: EventCategory {
        switch self {
        case .flight, .train, .bus, .car, .ferry, .hotel: return .travel
        case .restaurant, .nightlife: return .social
        case .museum, .tour, .beach, .hiking, .activity, .shopping, .other: return .general
        }
    }
}

extension Activity {
    func toPendingExpense(tripCurrency: String) -> Expense? {
        guard let cost, cost > 0 else { return nil }
        return Expense(
            title: title,
            amount: cost,
            currency: tripCurrency,
            category: category.asExpenseCategory,
            date: date,
            notes: notes,
            status: .pending,
            activityID: id,
            startTime: startTime,
            endTime: endTime
        )
    }
}
