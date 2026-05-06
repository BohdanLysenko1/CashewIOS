import Foundation

struct InviteLinkRecord: Sendable {
    let id: UUID
    let resourceType: String
    let resourceId: UUID
    let createdBy: UUID
    let expiresAt: Date
}

struct ShareInvitePreview: Equatable, Sendable {
    let resourceType: String
    let resourceId: UUID
    let createdBy: UUID
    let createdByName: String
    let title: String
    let expiresAt: Date
}

struct AcceptedShareInvite: Sendable {
    let resourceType: String
    let resourceId: UUID
}

struct PendingShareInvite: Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String?
    let invitedAt: Date
    let expiresAt: Date
}

protocol SharingDataStoreProtocol: AnyObject {
    func createInviteToken(resourceType: String, resourceId: UUID, createdBy: UUID) async throws -> String
    func previewInvite(token: String) async throws -> ShareInvitePreview
    func acceptInvite(token: String) async throws -> AcceptedShareInvite

    func fetchTrip(id: UUID) async throws -> Trip
    func fetchEvent(id: UUID) async throws -> Event

    func removeTripCollaborator(tripId: UUID, userId: UUID) async throws
    func removeEventCollaborator(eventId: UUID, userId: UUID) async throws

    func fetchTripCollaborators(tripId: UUID) async throws -> [AppUser]
    func fetchEventCollaborators(eventId: UUID) async throws -> [AppUser]

    func fetchPendingInvites(resourceType: String, resourceId: UUID, createdBy: UUID, after: Date) async throws -> [PendingShareInvite]
    func cancelInvite(id: UUID) async throws

    func fetchSharedByMeTripIds(userId: UUID) async throws -> Set<UUID>

    func fetchUser(id: UUID) async throws -> AppUser
}
