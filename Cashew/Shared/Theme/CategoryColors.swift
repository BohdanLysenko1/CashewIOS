import SwiftUI

// MARK: - Category Color Mappings
// All Color properties for Core model enums live here, keeping the Core layer free of SwiftUI.

extension EventCategory {
    var color: Color {
        switch self {
        case .general:       .blue
        case .meeting:       .purple
        case .social:        .pink
        case .entertainment: .orange
        case .sports:        .green
        case .health:        .red
        case .education:     .indigo
        case .work:          .gray
        case .travel:        .cyan
        case .custom:        .teal
        }
    }
}

extension TaskCategory {
    var color: Color {
        switch self {
        case .work:     .blue
        case .personal: .purple
        case .health:   .red
        case .errands:  .orange
        case .social:   .pink
        case .learning: .green
        case .custom:   .teal
        }
    }
}

extension ActivityCategory {
    var color: Color {
        switch self {
        case .flight, .train, .bus, .car, .ferry: .blue
        case .hotel:                              .purple
        case .restaurant:                         .orange
        case .museum, .tour:                      .brown
        case .beach:                              .cyan
        case .hiking:                             .green
        case .shopping:                           .pink
        case .nightlife:                          .indigo
        case .activity, .other:                   .gray
        }
    }
}

extension ExpenseCategory {
    var color: Color {
        switch self {
        case .accommodation:  .blue
        case .transportation: .green
        case .food:           .orange
        case .activities:     .purple
        case .shopping:       .pink
        case .entertainment:  .red
        case .health:         .mint
        case .communication:  .cyan
        case .other:          .gray
        }
    }
}

extension PackingCategory {
    var color: Color {
        switch self {
        case .clothing:      .blue
        case .toiletries:    .cyan
        case .electronics:   .purple
        case .documents:     .orange
        case .medicine:      .red
        case .accessories:   .pink
        case .entertainment: .indigo
        case .snacks:        .green
        case .other:         .gray
        }
    }
}
