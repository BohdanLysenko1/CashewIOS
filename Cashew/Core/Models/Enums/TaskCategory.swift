import Foundation

enum TaskCategory: String, Codable, Sendable, CaseIterable {
    case work
    case personal
    case health
    case errands
    case social
    case learning
    case custom

    var displayName: String {
        switch self {
        case .work: "Work"
        case .personal: "Personal"
        case .health: "Health"
        case .errands: "Errands"
        case .social: "Social"
        case .learning: "Learning"
        case .custom: "Custom"
        }
    }

    var icon: String {
        switch self {
        case .work: "briefcase.fill"
        case .personal: "person.fill"
        case .health: "heart.fill"
        case .errands: "cart.fill"
        case .social: "person.2.fill"
        case .learning: "book.fill"
        case .custom: "slider.horizontal.3"
        }
    }


}
