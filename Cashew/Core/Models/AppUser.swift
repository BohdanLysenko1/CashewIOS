import Foundation

struct AppUser: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let email: String
    var displayName: String
    var avatarPath: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarPath  = "avatar_url"
        case createdAt   = "created_at"
    }
}
