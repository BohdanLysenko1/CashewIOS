import Foundation

struct AppUser: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let email: String
    var displayName: String
    var avatarURL: URL?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL   = "avatar_url"
        case createdAt   = "created_at"
    }
}
