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

    func fetchInvite(token: String) async throws -> InviteLinkRecord {
        let invite: InviteLinkRow = try await client
            .from(SupabaseSchema.Table.inviteLinks)
            .select()
            .eq("token", value: token)
            .single()
            .execute()
            .value

        return InviteLinkRecord(
            id: invite.id,
            resourceType: invite.resourceType,
            resourceId: invite.resourceId,
            createdBy: invite.createdBy,
            expiresAt: invite.expiresAt
        )
    }

    func upsertTripShare(tripId: UUID, userId: UUID, invitedBy: UUID, acceptedAt: Date) async throws {
        try await client
            .from(SupabaseSchema.Table.tripShares)
            .upsert(TripSharePayload(
                trip_id: tripId,
                user_id: userId,
                invited_by: invitedBy,
                accepted_at: acceptedAt
            ))
            .execute()
    }

    func upsertEventShare(eventId: UUID, userId: UUID, invitedBy: UUID, acceptedAt: Date) async throws {
        try await client
            .from(SupabaseSchema.Table.eventShares)
            .upsert(EventSharePayload(
                event_id: eventId,
                user_id: userId,
                invited_by: invitedBy,
                accepted_at: acceptedAt
            ))
            .execute()
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
