import SwiftUI

struct ChangePasswordView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case new, confirm }

    private var passwordsMatch: Bool { newPassword == confirmPassword }
    private var isValid: Bool { newPassword.count >= 6 && passwordsMatch }

    private var validationError: String? {
        if !confirmPassword.isEmpty && !passwordsMatch {
            return "Passwords don't match."
        }
        if !newPassword.isEmpty && newPassword.count < 6 {
            return "Password must be at least 6 characters."
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: "Change Password",
                subtitle: "Set a new password for your account",
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    CreationSectionCard(title: "New Password", icon: "lock") {
                        VStack(spacing: AppTheme.Space.sm) {
                            SecureField("New password", text: $newPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .new)
                                .designField(isFocused: focusedField == .new)

                            SecureField("Confirm new password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirm)
                                .designField(isFocused: focusedField == .confirm)

                            CreationInlineError(text: validationError)

                            if let errorMessage {
                                CreationInlineError(text: errorMessage)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.bottom, AppTheme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Cancel",
                confirmTitle: "Save Password",
                gradient: AppTheme.dayPlannerGradient,
                canConfirm: isValid && !isSaving,
                isLoading: isSaving,
                onCancel: { dismiss() },
                onConfirm: { save() }
            )
        }
        .background(CreationScreenBackground(gradient: AppTheme.dayPlannerGradient))
    }

    private func save() {
        focusedField = nil
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await container.authService.updatePassword(newPassword)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
