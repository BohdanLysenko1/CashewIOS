import Foundation

@MainActor
protocol AuthServiceProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var isRestoringSession: Bool { get }
    var isRecoveringPassword: Bool { get }
    var currentUser: AppUser? { get }

    func signIn() async throws
    func signInWithEmail(email: String, password: String) async throws
    func signUpWithEmail(email: String, password: String, displayName: String) async throws
    func signOut() async throws
    func handleAuthCallback(url: URL) async throws
    func handlePasswordResetCallback(url: URL) async throws
    func updateDisplayName(_ name: String) async throws
    func updateAvatarImage(data: Data, contentType: String) async throws
    func removeAvatarImage() async throws
    func signedAvatarURL(for path: String, expiresIn: Int) async throws -> URL
    func updatePassword(_ newPassword: String) async throws
    func sendPasswordReset(email: String) async throws
    func deleteAccount() async throws
}
