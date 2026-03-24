import Foundation
import Observation

@Observable
@MainActor
final class MockAuthService: AuthServiceProtocol {

    private(set) var isAuthenticated = false
    private(set) var isRestoringSession = false
    private(set) var isRecoveringPassword = false
    private(set) var currentUser: AppUser? = nil

    func signIn() async throws {
        isAuthenticated = true
        currentUser = AppUser(id: UUID(), email: "test@example.com", displayName: "Test User", avatarURL: nil, createdAt: Date())
    }

    func signInWithEmail(email: String, password: String) async throws {
        isAuthenticated = true
        currentUser = AppUser(id: UUID(), email: email, displayName: email, avatarURL: nil, createdAt: Date())
    }

    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        isAuthenticated = true
        currentUser = AppUser(id: UUID(), email: email, displayName: displayName, avatarURL: nil, createdAt: Date())
    }

    func signOut() async throws {
        isAuthenticated = false
        isRecoveringPassword = false
        currentUser = nil
    }

    func handleAuthCallback(url: URL) async throws {}
    func handlePasswordResetCallback(url: URL) async throws {
        isRecoveringPassword = true
    }

    func updatePassword(_ newPassword: String) async throws {}
    func sendPasswordReset(email: String) async throws {}

    func updateDisplayName(_ name: String) async throws {
        currentUser?.displayName = name
    }
}
