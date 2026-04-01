import Foundation

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

    private let authService: AuthServiceProtocol
    private let dataStore: SharingDataStoreProtocol
    private let now: () -> Date

    var pendingInvites: [PendingInvite] = []

    init(
        authService: AuthServiceProtocol,
        dataStore: SharingDataStoreProtocol? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.authService = authService
        self.dataStore = dataStore ?? SupabaseSharingDataStore()
        self.now = now
    }

    // MARK: - Create Invite Link

    /// Generates a share link for a trip or event. Returns a deep link URL.
    func createInviteLink(for resource: SharedResource) async throws -> URL {
        let currentUserId = try currentUserIdOrThrow()
        let token = try await dataStore.createInviteToken(
            resourceType: resource.resourceType,
            resourceId: resource.resourceId,
            createdBy: currentUserId
        )
        return try ShareLinkCodec.makeInviteURL(token: token)
    }

    // MARK: - Accept Invite

    /// Accepts an invite by token. Returns the resource type and ID so the caller can navigate.
    func acceptInvite(token: String) async throws -> SharedResource {
        let currentUserId = try currentUserIdOrThrow()
        let invite = try await dataStore.fetchInvite(token: token)

        // 2. Check expiry
        if invite.expiresAt < now() {
            throw ShareError.expired
        }

        // 3. Insert share record and return resource
        switch invite.resourceType {
        case SharedResource.tripType:
            try await dataStore.upsertTripShare(
                tripId: invite.resourceId,
                userId: currentUserId,
                invitedBy: invite.createdBy,
                acceptedAt: now()
            )
            return .trip(try await dataStore.fetchTrip(id: invite.resourceId))

        case SharedResource.eventType:
            try await dataStore.upsertEventShare(
                eventId: invite.resourceId,
                userId: currentUserId,
                invitedBy: invite.createdBy,
                acceptedAt: now()
            )
            return .event(try await dataStore.fetchEvent(id: invite.resourceId))

        default:
            throw ShareError.unknownResourceType
        }
    }

    // MARK: - Remove Collaborator

    func removeCollaborator(userId: UUID, from resource: SharedResource) async throws {
        switch resource {
        case .trip(let trip):
            try await dataStore.removeTripCollaborator(tripId: trip.id, userId: userId)
        case .event(let event):
            try await dataStore.removeEventCollaborator(eventId: event.id, userId: userId)
        }
    }

    // MARK: - Fetch Collaborators

    func fetchCollaborators(for resource: SharedResource) async throws -> [AppUser] {
        switch resource {
        case .trip(let trip):
            return try await dataStore.fetchTripCollaborators(tripId: trip.id)
        case .event(let event):
            return try await dataStore.fetchEventCollaborators(eventId: event.id)
        }
    }

    func fetchUser(id: UUID) async throws -> AppUser {
        try await dataStore.fetchUser(id: id)
    }

    private func currentUserIdOrThrow() throws -> UUID {
        guard authService.isAuthenticated, let id = authService.currentUser?.id else {
            throw ShareError.notAuthenticated
        }
        return id
    }
}

// MARK: - Share Error

enum ShareError: LocalizedError, Equatable {
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
