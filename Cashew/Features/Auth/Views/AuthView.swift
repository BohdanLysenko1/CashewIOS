import SwiftUI

struct AuthView: View {

    @State private var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case username, email, password }

    init(viewModel: AuthViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        if viewModel.showEmailConfirmation {
            CheckEmailView(email: viewModel.email) {
                viewModel.showEmailConfirmation = false
                viewModel.mode = .signIn
                viewModel.password = ""
            }
        } else {
            authForm
        }
    }

    private var authForm: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    AppTheme.surfaceContainerLowest,
                    AppTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primaryGradient)
                                .frame(width: 80, height: 80)
                                .shadow(color: AppTheme.primary.opacity(0.35), radius: 16, x: 0, y: 8)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        Text("Cashew")
                            .font(AppTheme.TextStyle.heroTitle)
                            .foregroundStyle(AppTheme.onSurface)

                        Text("Plan smarter, together.")
                            .font(AppTheme.TextStyle.secondary)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                    // MARK: Card
                    VStack(spacing: 20) {

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
                        .background(AppTheme.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))

                        // Fields
                        VStack(spacing: 14) {
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

                            // Password field + forgot password inline
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Password")
                                        .font(AppTheme.TextStyle.captionBold)
                                        .foregroundStyle(AppTheme.onSurfaceVariant)
                                    Spacer()
                                    if viewModel.mode == .signIn {
                                        Button("Forgot password?") {
                                            viewModel.showForgotPassword = true
                                        }
                                        .font(AppTheme.TextStyle.captionBold)
                                        .foregroundStyle(AppTheme.primary)
                                    }
                                }

                                Group {
                                    SecureField(
                                        viewModel.mode == .signUp ? "At least 6 characters" : "••••••••",
                                        text: $viewModel.password
                                    )
                                    .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                                }
                                .font(.system(size: 16))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(AppTheme.surfaceContainer)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
                            }
                            .focused($focusedField, equals: .password)
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.mode)

                        // Error
                        if let error = viewModel.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error)
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.negative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Buttons
                        VStack(spacing: 12) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            } else {
                                // Primary
                                Button {
                                    focusedField = nil
                                    viewModel.submitEmail()
                                } label: {
                                    Text(viewModel.mode == .signIn ? "Sign In" : "Create Account")
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .foregroundStyle(AppTheme.onPrimary)
                                        .background(AppTheme.primaryGradient)
                                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)

                                        // Separator
                                HStack(spacing: 10) {
                                    Rectangle().frame(height: 1).foregroundStyle(AppTheme.outlineVariant)
                                    Text("or").font(AppTheme.TextStyle.caption).foregroundStyle(AppTheme.onSurfaceVariant)
                                    Rectangle().frame(height: 1).foregroundStyle(AppTheme.outlineVariant)
                                }

                                // Apple
                                Button {
                                    focusedField = nil
                                    viewModel.signInWithApple()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Continue with Apple")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .foregroundStyle(.white)
                                    .background(AppTheme.onSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                    .background(AppTheme.surfaceContainerLowest)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                    .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
                    .padding(.horizontal, 20)

                    Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                        .font(AppTheme.TextStyle.micro)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .onDisappear { viewModel.cancelSignIn() }
        .alert("Reset Password", isPresented: $viewModel.showForgotPassword) {
            TextField("Email address", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            Button("Send Reset Link") { viewModel.sendPasswordReset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your email and we'll send you a reset link.")
        }
        .alert("Email Sent", isPresented: $viewModel.passwordResetSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your inbox for a password reset link.")
        }
    }

    private func modeTab(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? AppTheme.onSurface : AppTheme.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selected
                        ? AppTheme.surfaceContainerLowest
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
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
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.onSurfaceVariant)

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
            .padding(.vertical, 14)
            .background(AppTheme.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
        }
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel(authService: MockAuthService()))
}
