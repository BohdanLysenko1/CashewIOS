import Foundation

struct AppUser: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let email: String
    var displayName: String
    var avatarPath: String?
    let createdAt: Date
    var totalXP: Int
    var xpUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarPath  = "avatar_url"
        case createdAt   = "created_at"
        case totalXP     = "total_xp"
        case xpUpdatedAt = "xp_updated_at"
    }

    init(
        id: UUID,
        email: String,
        displayName: String,
        avatarPath: String?,
        createdAt: Date,
        totalXP: Int = 0,
        xpUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarPath = avatarPath
        self.createdAt = createdAt
        self.totalXP = max(0, totalXP)
        self.xpUpdatedAt = xpUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decode(String.self, forKey: .displayName)
        avatarPath = try container.decodeIfPresent(String.self, forKey: .avatarPath)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        totalXP = max(0, try container.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0)
        xpUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .xpUpdatedAt)
    }
}
