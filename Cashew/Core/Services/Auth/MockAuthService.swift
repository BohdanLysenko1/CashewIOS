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
        currentUser = AppUser(id: UUID(), email: "test@example.com", displayName: "Test User", avatarPath: nil, createdAt: Date())
    }

    func signInWithEmail(email: String, password: String) async throws {
        isAuthenticated = true
        currentUser = AppUser(id: UUID(), email: email, displayName: email, avatarPath: nil, createdAt: Date())
    }

    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        isAuthenticated = true
        currentUser = AppUser(id: UUID(), email: email, displayName: displayName, avatarPath: nil, createdAt: Date())
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

    func deleteAccount() async throws {
        isAuthenticated = false
        currentUser = nil
    }

    func updateDisplayName(_ name: String) async throws {
        currentUser?.displayName = name
    }

    func updateAvatarImage(data: Data, contentType: String) async throws {
        guard let userId = currentUser?.id else { return }
        currentUser?.avatarPath = "\(userId.uuidString.lowercased())/avatar.jpg"
    }

    func removeAvatarImage() async throws {
        currentUser?.avatarPath = nil
    }

    func signedAvatarURL(for path: String, expiresIn: Int) async throws -> URL {
        URL(string: "https://example.com/\(path)") ?? URL(string: "https://example.com")!
    }
}
