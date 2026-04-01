import Foundation
import Supabase

// MARK: - Shared Resource

enum SharedResource {
    case trip(Trip)
    case event(Event)

    static let tripType  = "trip"
    static let eventType = "event"

    var resourceType: String {
        switch self {
        case .trip:  return SharedResource.tripType
        case .event: return SharedResource.eventType
        }
    }

    var resourceId: UUID {
        switch self {
        case .trip(let t):  return t.id
        case .event(let e): return e.id
        }
    }
}

// MARK: - Pending Invite

struct PendingInvite: Identifiable {
    let id: UUID
    let token: String
    let resourceType: String
    let resourceId: UUID
    let createdByName: String
    let expiresAt: Date
}

// MARK: - ShareService

@Observable
@MainActor
final class ShareService {

    private let client = SupabaseManager.client
    private let authService: AuthServiceProtocol

    var pendingInvites: [PendingInvite] = []

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    // MARK: - Create Invite Link

    /// Generates a share link for a trip or event. Returns a deep link URL.
    func createInviteLink(for resource: SharedResource) async throws -> URL {
        guard authService.isAuthenticated else { throw ShareError.notAuthenticated }
        let currentUserId = try await client.auth.session.user.id

        let row: InviteTokenRow = try await client
            .from(SupabaseSchema.Table.inviteLinks)
            .insert(InviteInsertPayload(
                resource_type: resource.resourceType,
                resource_id: resource.resourceId,
                created_by: currentUserId
            ))
            .select("token")
            .single()
            .execute()
            .value

        // Deep link format: cashew://join/<token>
        let pathAllowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard
            let encodedToken = row.token.addingPercentEncoding(withAllowedCharacters: pathAllowed),
            let url = URL(string: "cashew://join/\(encodedToken)")
        else {
            throw ShareError.invalidToken
        }
        return url
    }

    // MARK: - Accept Invite

    /// Accepts an invite by token. Returns the resource type and ID so the caller can navigate.
    func acceptInvite(token: String) async throws -> SharedResource {
        guard authService.isAuthenticated else { throw ShareError.notAuthenticated }
        let currentUserId = try await client.auth.session.user.id

        let invite: InviteLinkRow = try await client
            .from(SupabaseSchema.Table.inviteLinks)
            .select()
            .eq("token", value: token)
            .single()
            .execute()
            .value

        // 2. Check expiry
        if invite.expiresAt < Date() {
            throw ShareError.expired
        }

        // 3. Insert share record and return resource
        switch invite.resourceType {
        case SharedResource.tripType:
            try await client
                .from(SupabaseSchema.Table.tripShares)
                .upsert(TripSharePayload(
                    trip_id: invite.resourceId,
                    user_id: currentUserId,
                    invited_by: invite.createdBy,
                    accepted_at: Date()
                ))
                .execute()

            let trip: TripDTO = try await client
                .from(SupabaseSchema.Table.trips)
                .select(SupabaseSchema.Select.tripWithOwner)
                .eq("id", value: invite.resourceId.uuidString)
                .single()
                .execute()
                .value
            return .trip(trip.toTrip())

        case SharedResource.eventType:
            try await client
                .from(SupabaseSchema.Table.eventShares)
                .upsert(EventSharePayload(
                    event_id: invite.resourceId,
                    user_id: currentUserId,
                    invited_by: invite.createdBy,
                    accepted_at: Date()
                ))
                .execute()

            let event: EventDTO = try await client
                .from(SupabaseSchema.Table.events)
                .select(SupabaseSchema.Select.eventWithOwner)
                .eq("id", value: invite.resourceId.uuidString)
                .single()
                .execute()
                .value
            return .event(event.toEvent())

        default:
            throw ShareError.unknownResourceType
        }
    }

    // MARK: - Remove Collaborator

    func removeCollaborator(userId: UUID, from resource: SharedResource) async throws {
        switch resource {
        case .trip(let trip):
            try await client
                .from(SupabaseSchema.Table.tripShares)
                .delete()
                .eq("trip_id", value: trip.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        case .event(let event):
            try await client
                .from(SupabaseSchema.Table.eventShares)
                .delete()
                .eq("event_id", value: event.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        }
    }

    // MARK: - Fetch Collaborators

    func fetchCollaborators(for resource: SharedResource) async throws -> [AppUser] {
        let rows: [CollaboratorRow]
        switch resource {
        case .trip(let trip):
            rows = try await client
                .from(SupabaseSchema.Table.tripShares)
                .select(SupabaseSchema.Select.collaboratorRow)
                .eq("trip_id", value: trip.id.uuidString)
                .not("accepted_at", operator: .is, value: "null")
                .execute()
                .value
        case .event(let event):
            rows = try await client
                .from(SupabaseSchema.Table.eventShares)
                .select(SupabaseSchema.Select.collaboratorRow)
                .eq("event_id", value: event.id.uuidString)
                .not("accepted_at", operator: .is, value: "null")
                .execute()
                .value
        }

        return rows.map { $0.user }
    }

    func fetchUser(id: UUID) async throws -> AppUser {
        try await client
            .from(SupabaseSchema.Table.users)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }
}

// MARK: - Private DTOs

private struct InviteInsertPayload: Encodable {
    let resource_type: String
    let resource_id: UUID
    let created_by: UUID
}

private struct InviteTokenRow: Decodable {
    let token: String
}

private struct InviteLinkRow: Decodable {
    let id: UUID
    let resourceType: String
    let resourceId: UUID
    let createdBy: UUID
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case resourceType = "resource_type"
        case resourceId   = "resource_id"
        case createdBy    = "created_by"
        case expiresAt    = "expires_at"
    }
}

private struct TripSharePayload: Encodable {
    let trip_id: UUID
    let user_id: UUID
    let invited_by: UUID
    let accepted_at: Date
}

private struct EventSharePayload: Encodable {
    let event_id: UUID
    let user_id: UUID
    let invited_by: UUID
    let accepted_at: Date
}

private struct CollaboratorRow: Decodable {
    let user: AppUser
}

// MARK: - Share Error

enum ShareError: LocalizedError {
    case notAuthenticated
    case expired
    case invalidToken
    case unknownResourceType

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:    return "You must be signed in to share."
        case .expired:             return "This invite link has expired."
        case .invalidToken:        return "Invalid invite link."
        case .unknownResourceType: return "Unknown resource type."
        }
    }
}
