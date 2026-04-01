import Foundation
import XCTest
@testable import Cashew

@MainActor
final class ShareServiceTests: XCTestCase {

    func testCreateInviteLinkThrowsWhenNotAuthenticated() async {
        let auth = StubAuthService(isAuthenticated: false, currentUser: nil)
        let store = MockSharingDataStore()
        let service = ShareService(authService: auth, dataStore: store, now: fixedNow)

        do {
            _ = try await service.createInviteLink(for: .trip(makeTrip()))
            XCTFail("Expected notAuthenticated")
        } catch let error as ShareError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateInviteLinkUsesDataStoreAndReturnsDeepLink() async throws {
        let userID = UUID()
        let auth = StubAuthService(isAuthenticated: true, currentUser: makeUser(id: userID))
        let store = MockSharingDataStore()
        store.tokenToReturn = "a token/with spaces"
        let service = ShareService(authService: auth, dataStore: store, now: fixedNow)

        let trip = makeTrip()
        let url = try await service.createInviteLink(for: .trip(trip))

        XCTAssertEqual(url.scheme, "cashew")
        XCTAssertEqual(url.host, "join")
        XCTAssertEqual(ShareLinkCodec.parseInviteToken(from: url), "a token/with spaces")
        XCTAssertEqual(store.lastCreateInviteCall?.resourceType, SharedResource.tripType)
        XCTAssertEqual(store.lastCreateInviteCall?.resourceId, trip.id)
        XCTAssertEqual(store.lastCreateInviteCall?.createdBy, userID)
    }

    func testAcceptInviteThrowsExpired() async {
        let userID = UUID()
        let auth = StubAuthService(isAuthenticated: true, currentUser: makeUser(id: userID))
        let store = MockSharingDataStore()
        store.inviteToReturn = InviteLinkRecord(
            id: UUID(),
            resourceType: SharedResource.tripType,
            resourceId: UUID(),
            createdBy: UUID(),
            expiresAt: Date(timeIntervalSince1970: 50)
        )
        let service = ShareService(
            authService: auth,
            dataStore: store,
            now: { Date(timeIntervalSince1970: 100) }
        )

        do {
            _ = try await service.acceptInvite(token: "expired")
            XCTFail("Expected expired")
        } catch let error as ShareError {
            XCTAssertEqual(error, .expired)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAcceptInviteThrowsUnknownResourceType() async {
        let userID = UUID()
        let auth = StubAuthService(isAuthenticated: true, currentUser: makeUser(id: userID))
        let store = MockSharingDataStore()
        store.inviteToReturn = InviteLinkRecord(
            id: UUID(),
            resourceType: "unknown",
            resourceId: UUID(),
            createdBy: UUID(),
            expiresAt: Date(timeIntervalSince1970: 200)
        )
        let service = ShareService(
            authService: auth,
            dataStore: store,
            now: { Date(timeIntervalSince1970: 100) }
        )

        do {
            _ = try await service.acceptInvite(token: "unknown")
            XCTFail("Expected unknownResourceType")
        } catch let error as ShareError {
            XCTAssertEqual(error, .unknownResourceType)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAcceptInviteTripUpsertsShareAndReturnsTrip() async throws {
        let userID = UUID()
        let invitedBy = UUID()
        let trip = makeTrip()
        let auth = StubAuthService(isAuthenticated: true, currentUser: makeUser(id: userID))
        let store = MockSharingDataStore()
        store.inviteToReturn = InviteLinkRecord(
            id: UUID(),
            resourceType: SharedResource.tripType,
            resourceId: trip.id,
            createdBy: invitedBy,
            expiresAt: Date(timeIntervalSince1970: 200)
        )
        store.tripToReturn = trip

        let service = ShareService(
            authService: auth,
            dataStore: store,
            now: { Date(timeIntervalSince1970: 100) }
        )

        let resource = try await service.acceptInvite(token: "trip-token")
        guard case .trip(let returnedTrip) = resource else {
            XCTFail("Expected trip")
            return
        }
        XCTAssertEqual(returnedTrip.id, trip.id)
        XCTAssertEqual(store.lastTripShareUpsert?.resourceId, trip.id)
        XCTAssertEqual(store.lastTripShareUpsert?.userId, userID)
        XCTAssertEqual(store.lastTripShareUpsert?.invitedBy, invitedBy)
        XCTAssertEqual(store.lastTripShareUpsert?.acceptedAt, Date(timeIntervalSince1970: 100))
    }

    func testAcceptInviteEventUpsertsShareAndReturnsEvent() async throws {
        let userID = UUID()
        let invitedBy = UUID()
        let event = makeEvent()
        let auth = StubAuthService(isAuthenticated: true, currentUser: makeUser(id: userID))
        let store = MockSharingDataStore()
        store.inviteToReturn = InviteLinkRecord(
            id: UUID(),
            resourceType: SharedResource.eventType,
            resourceId: event.id,
            createdBy: invitedBy,
            expiresAt: Date(timeIntervalSince1970: 200)
        )
        store.eventToReturn = event

        let service = ShareService(
            authService: auth,
            dataStore: store,
            now: { Date(timeIntervalSince1970: 100) }
        )

        let resource = try await service.acceptInvite(token: "event-token")
        guard case .event(let returnedEvent) = resource else {
            XCTFail("Expected event")
            return
        }
        XCTAssertEqual(returnedEvent.id, event.id)
        XCTAssertEqual(store.lastEventShareUpsert?.resourceId, event.id)
        XCTAssertEqual(store.lastEventShareUpsert?.userId, userID)
        XCTAssertEqual(store.lastEventShareUpsert?.invitedBy, invitedBy)
        XCTAssertEqual(store.lastEventShareUpsert?.acceptedAt, Date(timeIntervalSince1970: 100))
    }

    func testFetchCollaboratorsRoutesByResourceType() async throws {
        let auth = StubAuthService(isAuthenticated: true, currentUser: makeUser())
        let store = MockSharingDataStore()
        let trip = makeTrip()
        let event = makeEvent()
        let tripCollaborator = makeUser(email: "trip@example.com")
        let eventCollaborator = makeUser(email: "event@example.com")
        store.tripCollaboratorsToReturn = [tripCollaborator]
        store.eventCollaboratorsToReturn = [eventCollaborator]
        let service = ShareService(authService: auth, dataStore: store, now: fixedNow)

        let tripUsers = try await service.fetchCollaborators(for: .trip(trip))
        let eventUsers = try await service.fetchCollaborators(for: .event(event))

        XCTAssertEqual(tripUsers, [tripCollaborator])
        XCTAssertEqual(eventUsers, [eventCollaborator])
        XCTAssertEqual(store.lastTripCollaboratorFetchId, trip.id)
        XCTAssertEqual(store.lastEventCollaboratorFetchId, event.id)
    }

    func testRemoveCollaboratorRoutesByResourceType() async throws {
        let auth = StubAuthService(isAuthenticated: true, currentUser: makeUser())
        let store = MockSharingDataStore()
        let trip = makeTrip()
        let event = makeEvent()
        let removedId = UUID()
        let service = ShareService(authService: auth, dataStore: store, now: fixedNow)

        try await service.removeCollaborator(userId: removedId, from: .trip(trip))
        try await service.removeCollaborator(userId: removedId, from: .event(event))

        XCTAssertEqual(store.lastTripCollaboratorRemoval?.resourceId, trip.id)
        XCTAssertEqual(store.lastTripCollaboratorRemoval?.userId, removedId)
        XCTAssertEqual(store.lastEventCollaboratorRemoval?.resourceId, event.id)
        XCTAssertEqual(store.lastEventCollaboratorRemoval?.userId, removedId)
    }

    func testFetchUserPassesThroughDataStore() async throws {
        let auth = StubAuthService(isAuthenticated: true, currentUser: makeUser())
        let store = MockSharingDataStore()
        let expected = makeUser(email: "lookup@example.com")
        store.userToReturn = expected
        let service = ShareService(authService: auth, dataStore: store, now: fixedNow)

        let user = try await service.fetchUser(id: expected.id)

        XCTAssertEqual(user, expected)
        XCTAssertEqual(store.lastFetchUserId, expected.id)
    }

    // MARK: - Fixtures

    private func fixedNow() -> Date {
        Date(timeIntervalSince1970: 100)
    }

    private func makeTrip(id: UUID = UUID()) -> Trip {
        Trip(
            id: id,
            name: "Rome",
            destination: "Rome",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000)
        )
    }

    private func makeEvent(id: UUID = UUID()) -> Event {
        Event(
            id: id,
            title: "Dinner",
            date: Date(timeIntervalSince1970: 2_000),
            location: "Center",
            category: .social
        )
    }

    private func makeUser(
        id: UUID = UUID(),
        email: String = "user@example.com",
        displayName: String = "User"
    ) -> AppUser {
        AppUser(
            id: id,
            email: email,
            displayName: displayName,
            avatarPath: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

// MARK: - Test Doubles

@MainActor
private final class StubAuthService: AuthServiceProtocol {
    var isAuthenticated: Bool
    var isRestoringSession = false
    var isRecoveringPassword = false
    var currentUser: AppUser?

    init(isAuthenticated: Bool, currentUser: AppUser?) {
        self.isAuthenticated = isAuthenticated
        self.currentUser = currentUser
    }

    func signIn() async throws {}
    func signInWithEmail(email: String, password: String) async throws {}
    func signUpWithEmail(email: String, password: String, displayName: String) async throws {}
    func signOut() async throws {}
    func handleAuthCallback(url: URL) async throws {}
    func handlePasswordResetCallback(url: URL) async throws {}
    func updateDisplayName(_ name: String) async throws {}
    func updateAvatarImage(data: Data, contentType: String) async throws {}
    func removeAvatarImage() async throws {}
    func signedAvatarURL(for path: String, expiresIn: Int) async throws -> URL {
        URL(string: "https://example.com")!
    }
    func updatePassword(_ newPassword: String) async throws {}
    func sendPasswordReset(email: String) async throws {}
}

@MainActor
private final class MockSharingDataStore: SharingDataStoreProtocol {
    struct CreateInviteCall {
        let resourceType: String
        let resourceId: UUID
        let createdBy: UUID
    }

    struct ShareUpsertCall {
        let resourceId: UUID
        let userId: UUID
        let invitedBy: UUID
        let acceptedAt: Date
    }

    struct CollaboratorRemovalCall {
        let resourceId: UUID
        let userId: UUID
    }

    var tokenToReturn = "token"
    var inviteToReturn = InviteLinkRecord(
        id: UUID(),
        resourceType: SharedResource.tripType,
        resourceId: UUID(),
        createdBy: UUID(),
        expiresAt: Date(timeIntervalSince1970: 10_000)
    )
    var tripToReturn = Trip(
        name: "Default Trip",
        destination: "Paris",
        startDate: Date(timeIntervalSince1970: 1_000),
        endDate: Date(timeIntervalSince1970: 2_000)
    )
    var eventToReturn = Event(
        title: "Default Event",
        date: Date(timeIntervalSince1970: 2_000),
        location: "Center",
        category: .social
    )
    var tripCollaboratorsToReturn: [AppUser] = []
    var eventCollaboratorsToReturn: [AppUser] = []
    var userToReturn = AppUser(
        id: UUID(),
        email: "default@example.com",
        displayName: "Default",
        avatarPath: nil,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    var lastCreateInviteCall: CreateInviteCall?
    var lastInviteLookupToken: String?
    var lastTripShareUpsert: ShareUpsertCall?
    var lastEventShareUpsert: ShareUpsertCall?
    var lastTripCollaboratorRemoval: CollaboratorRemovalCall?
    var lastEventCollaboratorRemoval: CollaboratorRemovalCall?
    var lastTripCollaboratorFetchId: UUID?
    var lastEventCollaboratorFetchId: UUID?
    var lastFetchUserId: UUID?

    func createInviteToken(resourceType: String, resourceId: UUID, createdBy: UUID) async throws -> String {
        lastCreateInviteCall = CreateInviteCall(resourceType: resourceType, resourceId: resourceId, createdBy: createdBy)
        return tokenToReturn
    }

    func fetchInvite(token: String) async throws -> InviteLinkRecord {
        lastInviteLookupToken = token
        return inviteToReturn
    }

    func upsertTripShare(tripId: UUID, userId: UUID, invitedBy: UUID, acceptedAt: Date) async throws {
        lastTripShareUpsert = ShareUpsertCall(resourceId: tripId, userId: userId, invitedBy: invitedBy, acceptedAt: acceptedAt)
    }

    func upsertEventShare(eventId: UUID, userId: UUID, invitedBy: UUID, acceptedAt: Date) async throws {
        lastEventShareUpsert = ShareUpsertCall(resourceId: eventId, userId: userId, invitedBy: invitedBy, acceptedAt: acceptedAt)
    }

    func fetchTrip(id: UUID) async throws -> Trip {
        tripToReturn
    }

    func fetchEvent(id: UUID) async throws -> Event {
        eventToReturn
    }

    func removeTripCollaborator(tripId: UUID, userId: UUID) async throws {
        lastTripCollaboratorRemoval = CollaboratorRemovalCall(resourceId: tripId, userId: userId)
    }

    func removeEventCollaborator(eventId: UUID, userId: UUID) async throws {
        lastEventCollaboratorRemoval = CollaboratorRemovalCall(resourceId: eventId, userId: userId)
    }

    func fetchTripCollaborators(tripId: UUID) async throws -> [AppUser] {
        lastTripCollaboratorFetchId = tripId
        return tripCollaboratorsToReturn
    }

    func fetchEventCollaborators(eventId: UUID) async throws -> [AppUser] {
        lastEventCollaboratorFetchId = eventId
        return eventCollaboratorsToReturn
    }

    func fetchUser(id: UUID) async throws -> AppUser {
        lastFetchUserId = id
        return userToReturn
    }
}
