import Foundation

enum EventCategory: String, Codable, Sendable, CaseIterable {
    case general
    case meeting
    case social
    case entertainment
    case sports
    case health
    case education
    case work
    case travel
    case custom

    var displayName: String {
        switch self {
        case .general: "General"
        case .meeting: "Meeting"
        case .social: "Social"
        case .entertainment: "Entertainment"
        case .sports: "Sports"
        case .health: "Health"
        case .education: "Education"
        case .work: "Work"
        case .travel: "Travel"
        case .custom: "Custom"
        }
    }

    var icon: String {
        switch self {
        case .general: "star"
        case .meeting: "person.2"
        case .social: "party.popper"
        case .entertainment: "film"
        case .sports: "figure.run"
        case .health: "heart"
        case .education: "book"
        case .work: "briefcase"
        case .travel: "airplane"
        case .custom: "slider.horizontal.3"
        }
    }


}
