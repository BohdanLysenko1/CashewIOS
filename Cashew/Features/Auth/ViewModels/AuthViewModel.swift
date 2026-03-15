import Foundation
import Observation

@Observable
@MainActor
final class AuthViewModel {

    enum Mode { case signIn, signUp }

    private let authService: AuthServiceProtocol
    private var signInTask: Task<Void, Never>?

    var mode: Mode = .signIn
    var email = ""
    var password = ""
    var username = ""
    var isLoading = false
    var errorMessage: String?

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    func submitEmail() {
        errorMessage = nil
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        if mode == .signUp && username.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Username is required."
            return
        }

        signInTask?.cancel()
        isLoading = true

        signInTask = Task {
            do {
                if mode == .signIn {
                    try await authService.signInWithEmail(email: email, password: password)
                } else {
                    try await authService.signUpWithEmail(
                        email: email,
                        password: password,
                        displayName: username.trimmingCharacters(in: .whitespaces)
                    )
                }
            } catch is CancellationError {
                // no-op
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func signInWithApple() {
        signInTask?.cancel()
        isLoading = true
        errorMessage = nil

        signInTask = Task {
            do {
                try await authService.signIn()
            } catch is CancellationError {
                // no-op
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
        signInTask = nil
        isLoading = false
    }
}
