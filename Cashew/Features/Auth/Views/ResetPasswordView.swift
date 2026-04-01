import SwiftUI

struct ResetPasswordView: View {

    @Environment(AppContainer.self) private var container

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case new, confirm }

    private var passwordsMatch: Bool { newPassword == confirmPassword }
    private var isValid: Bool { newPassword.count >= 6 && passwordsMatch }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.surfaceContainerLowest, AppTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.14))
                        .frame(width: 88, height: 88)
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }

                Spacer().frame(height: 24)

                VStack(spacing: 8) {
                    Text("Set New Password")
                        .font(.system(size: 26, weight: .bold))
                    Text("Choose a strong password for your account.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 36)

                // Card
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("New Password")
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        SecureField("At least 6 characters", text: $newPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .new)
                            .font(.system(size: 16))
                            .padding(.horizontal, 14).padding(.vertical, 13)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Password")
                            .font(AppTheme.TextStyle.caption).fontWeight(.medium)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        SecureField("Repeat your password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirm)
                            .font(.system(size: 16))
                            .padding(.horizontal, 14).padding(.vertical, 13)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous).strokeBorder(
                                !confirmPassword.isEmpty && !passwordsMatch ? AppTheme.tertiary : Color.clear,
                                lineWidth: !confirmPassword.isEmpty && !passwordsMatch ? 1.5 : 0
                            ))
                    }

                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords don't match.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer().frame(height: 4)

                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    } else {
                        Button(action: save) {
                            Text("Update Password")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(.white)
                                .background(
                                    LinearGradient(
                                        colors: isValid
                                            ? [AppTheme.primary, AppTheme.primaryDim]
                                            : [AppTheme.surfaceContainerHigh, AppTheme.surfaceContainerHigh],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: isValid ? AppTheme.primary.opacity(AppTheme.accentGlowOpacity) : .clear, radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isValid)
                    }
                }
                .padding(20)
                .background(AppTheme.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func save() {
        focusedField = nil
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await container.authService.updatePassword(newPassword)
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
                return
            }
            // Password changed — sign out so the user lands on the login screen.
            // If sign-out fails the password was still updated, so force-clear state.
            do {
                try await container.authService.signOut()
            } catch {
                errorMessage = "Password updated, but sign-out failed. Please restart the app."
                isSaving = false
            }
        }
    }
}
