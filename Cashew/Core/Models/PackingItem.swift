import Foundation

struct PackingItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var quantity: Int
    var isPacked: Bool
    var category: PackingCategory

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Int = 1,
        isPacked: Bool = false,
        category: PackingCategory = .other
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.isPacked = isPacked
        self.category = category
    }
}

enum PackingCategory: String, Codable, Sendable, CaseIterable {
    case clothing
    case toiletries
    case electronics
    case documents
    case medicine
    case accessories
    case entertainment
    case snacks
    case other

    var displayName: String {
        switch self {
        case .clothing: "Clothing"
        case .toiletries: "Toiletries"
        case .electronics: "Electronics"
        case .documents: "Documents"
        case .medicine: "Medicine"
        case .accessories: "Accessories"
        case .entertainment: "Entertainment"
        case .snacks: "Snacks"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .clothing: "tshirt.fill"
        case .toiletries: "drop.fill"
        case .electronics: "laptopcomputer"
        case .documents: "doc.fill"
        case .medicine: "pills.fill"
        case .accessories: "sunglasses.fill"
        case .entertainment: "book.fill"
        case .snacks: "takeoutbag.and.cup.and.straw.fill"
        case .other: "ellipsis.circle.fill"
        }
    }


}
