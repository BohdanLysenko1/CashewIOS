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

    // MARK: - Invite Preview

    func previewInvite(token: String) async throws -> ShareInvitePreview {
        _ = try currentUserIdOrThrow()
        let preview = try await dataStore.previewInvite(token: token)

        if preview.expiresAt < now() {
            throw ShareError.expired
        }

        switch preview.resourceType {
        case SharedResource.tripType, SharedResource.eventType:
            return preview
        default:
            throw ShareError.unknownResourceType
        }
    }

    // MARK: - Accept Invite

    /// Accepts an invite by token. Returns the resource type and ID so the caller can navigate.
    func acceptInvite(token: String) async throws -> SharedResource {
        _ = try currentUserIdOrThrow()
        let invite = try await dataStore.acceptInvite(token: token)

        switch invite.resourceType {
        case SharedResource.tripType:
            return .trip(try await dataStore.fetchTrip(id: invite.resourceId))

        case SharedResource.eventType:
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

    func fetchSharedTripIds() async throws -> Set<UUID> {
        let userId = try currentUserIdOrThrow()
        return try await dataStore.fetchSharedByMeTripIds(userId: userId)
    }

    // MARK: - Pending Invites

    func fetchPendingInvites(for resource: SharedResource) async throws -> [PendingShareInvite] {
        let userId = try currentUserIdOrThrow()
        return try await dataStore.fetchPendingInvites(
            resourceType: resource.resourceType,
            resourceId: resource.resourceId,
            createdBy: userId,
            after: now()
        )
    }

    func cancelPendingInvite(_ invite: PendingShareInvite, from resource: SharedResource) async throws {
        _ = resource // resource currently unused; reserved for future logging/permission checks
        try await dataStore.cancelInvite(id: invite.id)
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
