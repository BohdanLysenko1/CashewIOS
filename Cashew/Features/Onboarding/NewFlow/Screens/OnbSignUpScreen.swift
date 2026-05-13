import SwiftUI

struct OnbSignUpScreen: View {

    @Bindable var viewModel: AuthViewModel
    let isPremium: Bool
    let onComplete: () -> Void
    var onBack: (() -> Void)?

    @FocusState private var focusedField: Field?
    @State private var showEmailFields = false

    enum Field { case email, password, username }

    var body: some View {
        ZStack {
            backgroundLayer
            mainStack
        }
        .onChange(of: viewModel.showEmailConfirmation) { _, showing in
            if showing { focusedField = nil }
        }
        .sheet(isPresented: $viewModel.showEmailConfirmation) {
            CheckEmailView(email: viewModel.email) {
                viewModel.showEmailConfirmation = false
                viewModel.mode = .signIn
                viewModel.password = ""
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            OnbTheme.pageBackground.ignoresSafeArea()
            ZStack {
                OnbOrb(tint: .blue)
                OnbOrb(tint: .purple)
            }
            .ignoresSafeArea()
        }
    }

    private var mainStack: some View {
        VStack(spacing: 0) {
            topBar
            scrollContent
            footerActions
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                logo
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                headerText

                authButtonStack
                    .padding(.top, 24)
                    .padding(.horizontal, 8)

                errorRow
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var headerText: some View {
        VStack(spacing: 12) {
            if isPremium {
                OnbEyebrow(text: "7-Day Premium Trial Active",
                           icon: "sparkles",
                           goldStyle: true)
            }
            Text("Create your account")
                .font(OnbTheme.title(28))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Save your plans across every device. Free forever — upgrade anytime.")
                .font(OnbTheme.subtitle(14))
                .foregroundStyle(.white.opacity(0.70))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var authButtonStack: some View {
        VStack(spacing: 10) {
            appleButton
            if showEmailFields {
                emailFormFields
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                separator
                emailToggleButton
            }
        }
    }

    @ViewBuilder
    private var errorRow: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(error)
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.66))
            .padding(.top, 12)
        }
    }

    private var footerActions: some View {
        VStack(spacing: 8) {
            primaryFooterButton
            legalText
            modeSwitchButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var primaryFooterButton: some View {
        if viewModel.isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .frame(height: 54)
        } else {
            let icon: String? = showEmailFields ? "arrow.right" : nil
            OnbPrimaryButton(
                title: primaryActionTitle,
                trailingIcon: icon,
                action: handlePrimaryAction
            )
        }
    }

    private func handlePrimaryAction() {
        if showEmailFields {
            submitEmail()
        } else {
            signInWithApple()
        }
    }

    private var primaryActionTitle: String {
        if !showEmailFields { return "Continue with Apple" }
        if viewModel.mode == .signIn { return "Sign in" }
        return isPremium ? "Start my trial" : "Create account"
    }

    private var legalText: some View {
        Text("By continuing you agree to Cashew's Terms & Privacy Policy.")
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(.white.opacity(0.42))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 24)
    }

    private var modeSwitchButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                viewModel.mode = (viewModel.mode == .signIn) ? .signUp : .signIn
                viewModel.errorMessage = nil
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.mode == .signIn
                     ? "Don't have an account?"
                     : "Already have an account?")
                Text(viewModel.mode == .signIn ? "Sign up" : "Sign in")
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(8)
                }
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(OnbTheme.primarySoft.opacity(0.30))
                .frame(width: 130, height: 130)
                .blur(radius: 18)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 120, height: 120)
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            OnbPulseRing()
                .frame(width: 120, height: 120)
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 0.70, green: 0.86, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var appleButton: some View {
        Button(action: signInWithApple) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 16, weight: .semibold))
                Text("Continue with Apple")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var emailToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showEmailFields = true
                viewModel.errorMessage = nil
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Continue with email")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var separator: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            Text("OR")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.40))
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    private var emailFormFields: some View {
        VStack(spacing: 10) {
            if viewModel.mode == .signUp {
                onbField(placeholder: "Username", text: $viewModel.username,
                         icon: "person.fill",
                         contentType: .username,
                         keyboardType: .default,
                         field: .username)
            }
            onbField(placeholder: "your@email.com", text: $viewModel.email,
                     icon: "envelope.fill",
                     contentType: .emailAddress,
                     keyboardType: .emailAddress,
                     field: .email,
                     autocapitalize: false)
            onbField(placeholder: viewModel.mode == .signUp ? "At least 6 characters" : "Password",
                     text: $viewModel.password,
                     icon: "lock.fill",
                     contentType: viewModel.mode == .signUp ? .newPassword : .password,
                     keyboardType: .default,
                     field: .password,
                     isSecure: true)

            if viewModel.mode == .signIn {
                Button("Forgot password?") {
                    viewModel.showForgotPassword = true
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(OnbTheme.primarySoft)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 2)
            }
        }
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

    private func onbField(
        placeholder: String,
        text: Binding<String>,
        icon: String,
        contentType: UITextContentType,
        keyboardType: UIKeyboardType,
        field: Field,
        isSecure: Bool = false,
        autocapitalize: Bool = true
    ) -> some View {
        let isFocused = focusedField == field
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 18)
            Group {
                if isSecure {
                    SecureField("", text: text, prompt: Text(placeholder)
                        .foregroundStyle(.white.opacity(0.40)))
                } else {
                    TextField("", text: text, prompt: Text(placeholder)
                        .foregroundStyle(.white.opacity(0.40)))
                }
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .keyboardType(keyboardType)
            .textContentType(contentType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(autocapitalize ? .sentences : .never)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Color.white.opacity(isFocused ? 0.12 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused
                    ? OnbTheme.primarySoft.opacity(0.50)
                    : Color.white.opacity(0.14),
                    lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: focusedField)
    }

    // MARK: - Actions

    private func signInWithApple() {
        focusedField = nil
        viewModel.signInWithApple()
        // RootView observes auth state and will transition automatically.
        markCompleteOnSuccess()
    }

    private func submitEmail() {
        focusedField = nil
        viewModel.submitEmail()
        markCompleteOnSuccess()
    }

    /// Authentication is async — the parent RootView will switch to MainTabView
    /// once `authService.isAuthenticated` flips. We just signal completion here
    /// so the OnboardingFlow can mark the in-app spotlight tour as already seen.
    private func markCompleteOnSuccess() {
        Task { @MainActor in
            // Wait briefly for auth result, then notify on success.
            for _ in 0..<60 {  // up to ~6s
                if !viewModel.isLoading {
                    if viewModel.errorMessage == nil
                       && !viewModel.showEmailConfirmation {
                        // Either signed in successfully, or auth completed.
                        onComplete()
                    }
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
