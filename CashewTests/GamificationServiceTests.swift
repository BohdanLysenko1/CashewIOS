import Foundation
import XCTest
@testable import Cashew

@MainActor
final class GamificationServiceTests: XCTestCase {

    func testRefreshScopesXPPerUser() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { clear(defaults, suiteName: suiteName) }

        let auth = StubAuthService()
        auth.setUser(
            AppUser(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                email: "one@example.com",
                displayName: "One",
                avatarPath: nil,
                createdAt: Date(timeIntervalSince1970: 1_000),
                totalXP: 250
            )
        )

        let service = GamificationService(
            authService: auth,
            cloudStore: nil,
            userDefaults: defaults,
            nowProvider: { Date(timeIntervalSince1970: 2_000) }
        )

        await service.refreshForCurrentUser()
        XCTAssertEqual(service.totalXP, 250)

        service.award(xp: 100)
        XCTAssertEqual(service.totalXP, 350)

        auth.setUser(
            AppUser(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                email: "two@example.com",
                displayName: "Two",
                avatarPath: nil,
                createdAt: Date(timeIntervalSince1970: 1_100),
                totalXP: 20
            )
        )
        await service.refreshForCurrentUser()
        XCTAssertEqual(service.totalXP, 20)

        auth.setUser(
            AppUser(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                email: "one@example.com",
                displayName: "One",
                avatarPath: nil,
                createdAt: Date(timeIntervalSince1970: 1_000),
                totalXP: 250
            )
        )
        await service.refreshForCurrentUser()
        XCTAssertEqual(service.totalXP, 350)
    }

    func testRefreshUsesMostRecentRemoteXPState() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { clear(defaults, suiteName: suiteName) }

        let userId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let auth = StubAuthService()
        auth.setUser(
            AppUser(
                id: userId,
                email: "remote@example.com",
                displayName: "Remote",
                avatarPath: nil,
                createdAt: Date(timeIntervalSince1970: 1_000),
                totalXP: 100
            )
        )

        let remoteUpdatedAt = Date(timeIntervalSince1970: 5_000)
        let cloudStore = StubGamificationCloudStore(
            state: GamificationCloudState(totalXP: 800, updatedAt: remoteUpdatedAt)
        )

        defaults.set(100, forKey: "gam_totalXP_\(userId.uuidString.lowercased())")
        defaults.set(2_000.0, forKey: "gam_totalXP_updated_at_\(userId.uuidString.lowercased())")

        let service = GamificationService(
            authService: auth,
            cloudStore: cloudStore,
            userDefaults: defaults,
            nowProvider: { Date(timeIntervalSince1970: 2_000) }
        )

        await service.refreshForCurrentUser()

        XCTAssertEqual(service.totalXP, 800)
        XCTAssertEqual(cloudStore.upserts.count, 0)

        let storedEpoch = defaults.double(forKey: "gam_totalXP_updated_at_\(userId.uuidString.lowercased())")
        XCTAssertEqual(Date(timeIntervalSince1970: storedEpoch), remoteUpdatedAt)
    }

    private func makeIsolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "GamificationServiceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create isolated defaults suite")
        }
        return (defaults, suiteName)
    }

    private func clear(_ defaults: UserDefaults, suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class StubAuthService: AuthServiceProtocol {
    var isAuthenticated: Bool { currentUser != nil }
    var isRestoringSession: Bool = false
    var isRecoveringPassword: Bool = false
    private(set) var currentUser: AppUser?

    func setUser(_ user: AppUser?) {
        currentUser = user
    }

    func signIn() async throws {}
    func signInWithEmail(email: String, password: String) async throws {}
    func signUpWithEmail(email: String, password: String, displayName: String) async throws {}
    func signOut() async throws { currentUser = nil }
    func handleAuthCallback(url: URL) async throws {}
    func handlePasswordResetCallback(url: URL) async throws {}
    func updateDisplayName(_ name: String) async throws {}
    func updateAvatarImage(data: Data, contentType: String) async throws {}
    func removeAvatarImage() async throws {}
    func signedAvatarURL(for path: String, expiresIn: Int) async throws -> URL { URL(string: "https://example.com")! }
    func updatePassword(_ newPassword: String) async throws {}
    func sendPasswordReset(email: String) async throws {}
}

@MainActor
private final class StubGamificationCloudStore: GamificationCloudStore {
    var state: GamificationCloudState
    private(set) var upserts: [(userId: UUID, totalXP: Int, updatedAt: Date)] = []

    init(state: GamificationCloudState) {
        self.state = state
    }

    func fetchState(for userId: UUID) async throws -> GamificationCloudState {
        state
    }

    func upsertState(for userId: UUID, totalXP: Int, updatedAt: Date) async throws {
        upserts.append((userId: userId, totalXP: totalXP, updatedAt: updatedAt))
    }
}
