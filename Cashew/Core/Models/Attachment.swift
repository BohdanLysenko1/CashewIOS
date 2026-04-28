import Foundation

struct Attachment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var type: AttachmentType
    var url: URL?
    var localPath: String?
    var storagePath: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: AttachmentType,
        url: URL? = nil,
        localPath: String? = nil,
        storagePath: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.localPath = localPath
        self.storagePath = storagePath
        self.createdAt = createdAt
    }
}

enum AttachmentType: String, Codable, Sendable, CaseIterable {
    case link
    case image
    case document
    case ticket
    case reservation
    case other

    var displayName: String {
        switch self {
        case .link: "Link"
        case .image: "Image"
        case .document: "Document"
        case .ticket: "Ticket"
        case .reservation: "Reservation"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .link: "link"
        case .image: "photo.fill"
        case .document: "doc.fill"
        case .ticket: "ticket.fill"
        case .reservation: "calendar.badge.checkmark"
        case .other: "paperclip"
        }
    }
}
