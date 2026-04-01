import Foundation

struct InviteLinkRecord: Sendable {
    let id: UUID
    let resourceType: String
    let resourceId: UUID
    let createdBy: UUID
    let expiresAt: Date
}

protocol SharingDataStoreProtocol: AnyObject {
    func createInviteToken(resourceType: String, resourceId: UUID, createdBy: UUID) async throws -> String
    func fetchInvite(token: String) async throws -> InviteLinkRecord

    func upsertTripShare(tripId: UUID, userId: UUID, invitedBy: UUID, acceptedAt: Date) async throws
    func upsertEventShare(eventId: UUID, userId: UUID, invitedBy: UUID, acceptedAt: Date) async throws

    func fetchTrip(id: UUID) async throws -> Trip
    func fetchEvent(id: UUID) async throws -> Event

    func removeTripCollaborator(tripId: UUID, userId: UUID) async throws
    func removeEventCollaborator(eventId: UUID, userId: UUID) async throws

    func fetchTripCollaborators(tripId: UUID) async throws -> [AppUser]
    func fetchEventCollaborators(eventId: UUID) async throws -> [AppUser]

    func fetchUser(id: UUID) async throws -> AppUser
}
