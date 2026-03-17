import Foundation
import Observation
import Supabase
import AuthenticationServices
import CryptoKit

@Observable
@MainActor
final class SupabaseAuthService: AuthServiceProtocol {

    private(set) var isAuthenticated = false
    private(set) var isRestoringSession = true
    private(set) var currentUser: AppUser? = nil

    private let client = SupabaseManager.client
    private var currentNonce: String?

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Session Restore

    private func restoreSession() async {
        do {
            let session = try await client.auth.session
            isAuthenticated = true
            await fetchCurrentUser(id: session.user.id)
        } catch {
            isAuthenticated = false
        }
        isRestoringSession = false
    }

    // MARK: - Apple Sign In

    func signIn() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce

        let credential = try await performAppleSignIn(nonce: nonce)

        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.invalidCredential
        }

        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        // Update display name on first sign-in if Apple provided one
        if let fullName = credential.fullName,
           let given = fullName.givenName,
           let family = fullName.familyName {
            let name = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
            do {
                _ = try await client
                    .from(SupabaseSchema.Table.users)
                    .update(["display_name": name])
                    .eq("id", value: session.user.id.uuidString)
                    .execute()
            } catch {
                print("[SupabaseAuthService] Failed to update display name: \(error)")
            }
        }

        isAuthenticated = true
        await fetchCurrentUser(id: session.user.id)
    }

    // MARK: - Email / Password

    func signInWithEmail(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        isAuthenticated = true
        await fetchCurrentUser(id: session.user.id)
        // If profile row is missing (e.g. first email sign-in), create it
        if currentUser == nil {
            do {
                _ = try await client
                    .from(SupabaseSchema.Table.users)
                    .upsert([
                        "id": session.user.id.uuidString,
                        "email": email,
                        "display_name": email.components(separatedBy: "@").first ?? email
                    ])
                    .execute()
            } catch {
                print("[SupabaseAuthService] Failed to create profile on first sign-in: \(error)")
            }
            await fetchCurrentUser(id: session.user.id)
        }
    }

    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )
        isAuthenticated = true
        await fetchCurrentUser(id: response.user.id)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        isAuthenticated = false
        currentUser = nil
    }

    // MARK: - User Fetch

    func fetchCurrentUser(id: UUID) async {
        do {
            let user: AppUser = try await client
                .from(SupabaseSchema.Table.users)
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
            currentUser = user
        } catch {
            print("[SupabaseAuthService] Could not fetch user profile for \(id): \(error)")
        }
    }

    // MARK: - Apple Sign In Helper

    private func performAppleSignIn(nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let delegate = AppleSignInDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            // Retain delegate for the duration of the request
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidCredential
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid Apple credential."
        case .cancelled: return "Sign in was cancelled."
        }
    }
}

// MARK: - Apple Sign In Delegate

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {

    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: credential)
        } else {
            continuation.resume(throwing: AuthError.invalidCredential)
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if (error as? ASAuthorizationError)?.code == .canceled {
            continuation.resume(throwing: AuthError.cancelled)
        } else {
            continuation.resume(throwing: error)
        }
    }
}
