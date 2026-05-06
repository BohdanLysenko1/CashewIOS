import Foundation
import Supabase

@MainActor
final class SupabaseSharingDataStore: SharingDataStoreProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient? = nil) {
        self.client = client ?? SupabaseManager.client
    }

    func createInviteToken(resourceType: String, resourceId: UUID, createdBy: UUID) async throws -> String {
        let row: InviteTokenRow = try await client
            .from(SupabaseSchema.Table.inviteLinks)
            .insert(InviteInsertPayload(
                resource_type: resourceType,
                resource_id: resourceId,
                created_by: createdBy
            ))
            .select("token")
            .single()
            .execute()
            .value

        return row.token
    }

    func previewInvite(token: String) async throws -> ShareInvitePreview {
        let row: InvitePreviewRow = try await client
            .rpc("preview_share_invite", params: ["p_token": token])
            .single()
            .execute()
            .value

        return row.toPreview()
    }

    func acceptInvite(token: String) async throws -> AcceptedShareInvite {
        let row: AcceptedInviteRow = try await client
            .rpc("accept_share_invite", params: ["p_token": token])
            .single()
            .execute()
            .value
        return AcceptedShareInvite(resourceType: row.resourceType, resourceId: row.resourceId)
    }

    func fetchTrip(id: UUID) async throws -> Trip {
        let trip: TripDTO = try await client
            .from(SupabaseSchema.Table.trips)
            .select(SupabaseSchema.Select.tripWithOwner)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return trip.toTrip()
    }

    func fetchEvent(id: UUID) async throws -> Event {
        let event: EventDTO = try await client
            .from(SupabaseSchema.Table.events)
            .select(SupabaseSchema.Select.eventWithOwner)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return event.toEvent()
    }

    func removeTripCollaborator(tripId: UUID, userId: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.tripShares)
            .delete()
            .eq("trip_id", value: tripId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func removeEventCollaborator(eventId: UUID, userId: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.eventShares)
            .delete()
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func fetchTripCollaborators(tripId: UUID) async throws -> [AppUser] {
        let rows: [CollaboratorRow] = try await client
            .from(SupabaseSchema.Table.tripShares)
            .select(SupabaseSchema.Select.collaboratorRow)
            .eq("trip_id", value: tripId.uuidString)
            .not("accepted_at", operator: .is, value: "null")
            .execute()
            .value
        return rows.map(\.user)
    }

    func fetchEventCollaborators(eventId: UUID) async throws -> [AppUser] {
        let rows: [CollaboratorRow] = try await client
            .from(SupabaseSchema.Table.eventShares)
            .select(SupabaseSchema.Select.collaboratorRow)
            .eq("event_id", value: eventId.uuidString)
            .not("accepted_at", operator: .is, value: "null")
            .execute()
            .value
        return rows.map(\.user)
    }

    func fetchSharedByMeTripIds(userId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let trip_id: UUID }
        let rows: [Row] = try await client
            .from(SupabaseSchema.Table.tripShares)
            .select("trip_id")
            .eq("invited_by", value: userId.uuidString)
            .not("accepted_at", operator: .is, value: "null")
            .execute()
            .value
        return Set(rows.map(\.trip_id))
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

    func fetchPendingInvites(
        resourceType: String,
        resourceId: UUID,
        createdBy: UUID,
        after: Date
    ) async throws -> [PendingShareInvite] {
        let rows: [PendingInviteRow] = try await client
            .from(SupabaseSchema.Table.inviteLinks)
            .select("id, created_at, expires_at")
            .eq("resource_type", value: resourceType)
            .eq("resource_id", value: resourceId.uuidString)
            .eq("created_by", value: createdBy.uuidString)
            .gt("expires_at", value: ISO8601DateFormatter().string(from: after))
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { row in
            PendingShareInvite(
                id: row.id,
                displayName: nil,
                invitedAt: row.createdAt ?? row.expiresAt.addingTimeInterval(-7 * 24 * 60 * 60),
                expiresAt: row.expiresAt
            )
        }
    }

    func cancelInvite(id: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.inviteLinks)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - DTOs

private struct InviteInsertPayload: Encodable {
    let resource_type: String
    let resource_id: UUID
    let created_by: UUID
}

private struct InviteTokenRow: Decodable {
    let token: String
}

private struct InvitePreviewRow: Decodable {
    let resourceType: String
    let resourceId: UUID
    let createdBy: UUID
    let createdByName: String
    let title: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case resourceType = "resource_type"
        case resourceId   = "resource_id"
        case createdBy    = "created_by"
        case createdByName = "created_by_name"
        case title
        case expiresAt    = "expires_at"
    }

    func toPreview() -> ShareInvitePreview {
        ShareInvitePreview(
            resourceType: resourceType,
            resourceId: resourceId,
            createdBy: createdBy,
            createdByName: createdByName,
            title: title,
            expiresAt: expiresAt
        )
    }
}

private struct AcceptedInviteRow: Decodable {
    let resourceType: String
    let resourceId: UUID

    enum CodingKeys: String, CodingKey {
        case resourceType = "resource_type"
        case resourceId = "resource_id"
    }
}

private struct CollaboratorRow: Decodable {
    let user: AppUser
}

private struct PendingInviteRow: Decodable {
    let id: UUID
    let createdAt: Date?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}
