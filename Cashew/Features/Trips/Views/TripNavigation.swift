import Foundation

enum TripSection: Hashable {
    case budget
    case itinerary
    case packing
    case checklist
}

enum TripSectionIntent: Hashable {
    case overview
    case addExpense
    case addActivity
    case addPackingItem
    case addChecklistItem
    case reviewPacking
    case reviewChecklist
    case generateAI
}

struct TripRoute: Hashable {
    let section: TripSection
    let intent: TripSectionIntent

    init(section: TripSection, intent: TripSectionIntent = .overview) {
        self.section = section
        self.intent = intent
    }
}
