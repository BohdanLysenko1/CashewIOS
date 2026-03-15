import SwiftUI

struct AuthView: View {

    @State private var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case username, email, password }

    init(viewModel: AuthViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Logo
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: Color.blue.opacity(0.35), radius: 12, x: 0, y: 6)

                        Text("Cashew")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Plan smarter, together.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 36)

                    // Mode toggle
                    HStack(spacing: 0) {
                        modeTab(title: "Sign In", selected: viewModel.mode == .signIn) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.mode = .signIn
                                viewModel.errorMessage = nil
                            }
                        }
                        modeTab(title: "Create Account", selected: viewModel.mode == .signUp) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.mode = .signUp
                                viewModel.errorMessage = nil
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)

                    // Form card
                    VStack(spacing: 12) {
                        if viewModel.mode == .signUp {
                            AuthField(
                                label: "Username",
                                placeholder: "e.g. johndoe",
                                text: $viewModel.username,
                                contentType: .username,
                                keyboardType: .default,
                                isSecure: false
                            )
                            .focused($focusedField, equals: .username)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        AuthField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $viewModel.email,
                            contentType: .emailAddress,
                            keyboardType: .emailAddress,
                            isSecure: false
                        )
                        .focused($focusedField, equals: .email)
                        .autocapitalization(.none)

                        AuthField(
                            label: "Password",
                            placeholder: viewModel.mode == .signUp ? "At least 6 characters" : "••••••••",
                            text: $viewModel.password,
                            contentType: viewModel.mode == .signUp ? .newPassword : .password,
                            keyboardType: .default,
                            isSecure: true
                        )
                        .focused($focusedField, equals: .password)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.mode)

                    // Error
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Primary button
                    VStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        } else {
                            Button(action: {
                                focusedField = nil
                                viewModel.submitEmail()
                            }) {
                                Text(viewModel.mode == .signIn ? "Sign In" : "Create Account")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .foregroundStyle(.white)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.indigo],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)

                            // Divider
                            HStack(spacing: 10) {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color(.separator))
                                Text("or")
                                    .font(.caption)
                                    .foregroundStyle(Color(.tertiaryLabel))
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color(.separator))
                            }

                            // Apple Sign In
                            Button(action: {
                                focusedField = nil
                                viewModel.signInWithApple()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Continue with Apple")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(.white)
                                .background(Color(.label))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .onDisappear { viewModel.cancelSignIn() }
    }

    private func modeTab(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selected
                        ? Color(.systemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                        : nil
                )
                .padding(4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selected)
    }
}

// MARK: - Auth Field

private struct AuthField: View {

    let label: String
    let placeholder: String
    @Binding var text: String
    let contentType: UITextContentType
    let keyboardType: UIKeyboardType
    let isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color(.secondaryLabel))

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocorrectionDisabled()
                }
            }
            .textContentType(contentType)
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel(authService: MockAuthService()))
}
