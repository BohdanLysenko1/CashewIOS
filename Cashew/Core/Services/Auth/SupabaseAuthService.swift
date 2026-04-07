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
    private(set) var isRecoveringPassword = false
    private(set) var currentUser: AppUser? = nil

    private let client = SupabaseManager.client
    private var currentNonce: String?
    private static var delegateKey: UInt8 = 0
    private static let avatarBucket = "avatars"

    init() {
        Task { await restoreSession() }
        Task { await listenToAuthEvents() }
    }

    private func listenToAuthEvents() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .passwordRecovery:
                isAuthenticated = true
                isRecoveringPassword = true
                if let id = session?.user.id {
                    await fetchCurrentUser(id: id)
                }
            case .signedIn:
                // Handles deep-link callbacks (email confirmation, invite links).
                // Direct sign-in methods (signInWithEmail, signIn, etc.) set state
                // themselves, so skip if already authenticated to avoid redundant work.
                guard !isAuthenticated else { break }
                isAuthenticated = true
                if let id = session?.user.id {
                    await fetchCurrentUser(id: id)
                }
            case .signedOut:
                // Handles server-side session expiry or token revocation.
                isAuthenticated = false
                isRecoveringPassword = false
                currentUser = nil
            default:
                break
            }
        }
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
                    .update(DisplayNameUpdatePayload(displayName: name))
                    .eq("id", value: session.user.id.uuidString)
                    .select()
                    .single()
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
            let baseName = email.components(separatedBy: "@").first ?? email
            do {
                _ = try await client
                    .from(SupabaseSchema.Table.users)
                    .upsert([
                        "id": session.user.id.uuidString,
                        "email": email,
                        "display_name": baseName
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
            data: [
                "display_name": .string(displayName)
            ],
            redirectTo: URL(string: "cashew://login-callback")
        )
        // If email confirmation is required, session is nil until the user confirms
        guard response.session != nil else {
            throw AuthError.emailConfirmationRequired
        }
        isAuthenticated = true
        await fetchCurrentUser(id: response.user.id)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        isAuthenticated = false
        isRecoveringPassword = false
        currentUser = nil
    }

    func handleAuthCallback(url: URL) async throws {
        // Just exchange the code/token with Supabase. The resulting auth state
        // change (.signedIn or .passwordRecovery) is handled by listenToAuthEvents,
        // which sets isAuthenticated and isRecoveringPassword appropriately.
        _ = try await client.auth.session(from: url)
    }

    func handlePasswordResetCallback(url: URL) async throws {
        // Set the flag *before* exchanging the token so the UI never
        // flashes MainTabView when the .signedIn event fires first.
        isRecoveringPassword = true
        _ = try await client.auth.session(from: url)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: URL(string: "cashew://reset-callback"))
    }

    func updateDisplayName(_ name: String) async throws {
        guard let userId = currentUser?.id else { return }
        let updated: AppUser = try await client
            .from(SupabaseSchema.Table.users)
            .update(DisplayNameUpdatePayload(displayName: name))
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
        currentUser = updated
    }

    func updateAvatarImage(data: Data, contentType: String) async throws {
        guard let userId = currentUser?.id else { return }
        let avatarPath = "\(userId.uuidString.lowercased())/avatar.jpg"

        try await client.storage
            .from(Self.avatarBucket)
            .upload(
                avatarPath,
                data: data,
                options: FileOptions(contentType: contentType, upsert: true)
            )

        let updated: AppUser = try await client
            .from(SupabaseSchema.Table.users)
            .update(AvatarPathUpdatePayload(avatarPath: avatarPath))
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
        currentUser = updated
    }

    func removeAvatarImage() async throws {
        guard let userId = currentUser?.id else { return }
        let existingPath = currentUser?.avatarPath

        if let existingPath, !existingPath.isEmpty {
            _ = try? await client.storage
                .from(Self.avatarBucket)
                .remove(paths: [existingPath])
        }

        let updated: AppUser = try await client
            .from(SupabaseSchema.Table.users)
            .update(AvatarPathUpdatePayload(avatarPath: nil))
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
        currentUser = updated
    }

    func signedAvatarURL(for path: String, expiresIn: Int) async throws -> URL {
        try await client.storage
            .from(Self.avatarBucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }

    // MARK: - User Fetch

    private func fetchCurrentUser(id: UUID) async {
        // Always get the canonical email from the auth session
        let authEmail = (try? await client.auth.session.user.email) ?? ""

        do {
            let user: AppUser = try await client
                .from(SupabaseSchema.Table.users)
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            // Sync email if it's empty or out of date
            if !authEmail.isEmpty, user.email != authEmail {
                _ = try? await client
                    .from(SupabaseSchema.Table.users)
                    .update(["email": authEmail])
                    .eq("id", value: id.uuidString)
                    .execute()
                currentUser = AppUser(
                    id: user.id,
                    email: authEmail,
                    displayName: user.displayName,
                    avatarPath: user.avatarPath,
                    createdAt: user.createdAt
                )
            } else {
                currentUser = user
            }
        } catch {
            // Row doesn't exist yet — create it from auth metadata
            await createProfileRow(id: id, email: authEmail)
        }
    }

    private func createProfileRow(id: UUID, email: String) async {
        do {
            let displayName = (try? await client.auth.session.user.userMetadata["display_name"]?.stringValue)
                ?? email.components(separatedBy: "@").first
                ?? "User"

            let user: AppUser = try await client
                .from(SupabaseSchema.Table.users)
                .insert([
                    "id": id.uuidString,
                    "email": email,
                    "display_name": displayName
                ])
                .select()
                .single()
                .execute()
                .value
            currentUser = user
        } catch {
            print("[SupabaseAuthService] Failed to create profile for \(id): \(error)")
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
            objc_setAssociatedObject(controller, &SupabaseAuthService.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
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

private struct AvatarPathUpdatePayload: Encodable {
    let avatarPath: String?

    enum CodingKeys: String, CodingKey {
        case avatarPath = "avatar_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let avatarPath {
            try container.encode(avatarPath, forKey: .avatarPath)
        } else {
            try container.encodeNil(forKey: .avatarPath)
        }
    }
}

private struct DisplayNameUpdatePayload: Encodable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidCredential
    case cancelled
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid Apple credential."
        case .cancelled: return "Sign in was cancelled."
        case .emailConfirmationRequired: return "Check your inbox and confirm your email to continue."
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
