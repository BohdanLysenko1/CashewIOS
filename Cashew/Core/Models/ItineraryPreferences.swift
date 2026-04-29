import Foundation

struct ItineraryInterest: Identifiable, Hashable {
    let id: String
    let displayName: String
    let icon: String

    static let catalog: [ItineraryInterest] = [
        .init(id: "restaurant",  displayName: "Restaurants", icon: "fork.knife"),
        .init(id: "foodie",      displayName: "Local Food",  icon: "carrot.fill"),
        .init(id: "museum",      displayName: "Museums",     icon: "building.columns.fill"),
        .init(id: "art",         displayName: "Art",         icon: "paintpalette.fill"),
        .init(id: "history",     displayName: "History",     icon: "scroll.fill"),
        .init(id: "tour",        displayName: "Tours",       icon: "figure.walk"),
        .init(id: "nature",      displayName: "Nature",      icon: "leaf.fill"),
        .init(id: "hiking",      displayName: "Hiking",      icon: "figure.hiking"),
        .init(id: "beach",       displayName: "Beach",       icon: "beach.umbrella.fill"),
        .init(id: "photography", displayName: "Photography", icon: "camera.fill"),
        .init(id: "shopping",    displayName: "Shopping",    icon: "bag.fill"),
        .init(id: "wellness",    displayName: "Wellness",    icon: "leaf.circle.fill"),
        .init(id: "nightlife",   displayName: "Nightlife",   icon: "moon.stars.fill"),
        .init(id: "activity",    displayName: "Activities",  icon: "star.fill"),
    ]
}

enum TripVibe: String, CaseIterable, Identifiable, Hashable {
    case adventurous
    case cultural
    case romantic
    case family
    case party
    case solo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .adventurous: "Adventurous"
        case .cultural:    "Cultural"
        case .romantic:    "Romantic"
        case .family:      "Family"
        case .party:       "Party"
        case .solo:        "Solo"
        }
    }

    var icon: String {
        switch self {
        case .adventurous: "mountain.2.fill"
        case .cultural:    "building.columns.fill"
        case .romantic:    "heart.fill"
        case .family:      "figure.2.and.child.holdinghands"
        case .party:       "music.mic"
        case .solo:        "person.fill"
        }
    }
}

enum TripPace: String, CaseIterable, Identifiable, Hashable {
    case relaxed
    case balanced
    case packed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relaxed:  "Relaxed"
        case .balanced: "Balanced"
        case .packed:   "Packed"
        }
    }

    var subtitle: String {
        switch self {
        case .relaxed:  "2–3/day"
        case .balanced: "3–4/day"
        case .packed:   "4–5/day"
        }
    }
}
