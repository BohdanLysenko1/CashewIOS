import Foundation

@MainActor
protocol AuthServiceProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var isRestoringSession: Bool { get }
    var currentUser: AppUser? { get }

    func signIn() async throws
    func signInWithEmail(email: String, password: String) async throws
    func signUpWithEmail(email: String, password: String, displayName: String) async throws
    func signOut() async throws
}
