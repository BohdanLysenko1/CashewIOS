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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .new)

                    SecureField("Confirm new password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirm)
                } footer: {
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords don't match.")
                            .foregroundStyle(AppTheme.negative)
                    } else {
                        Text("At least 6 characters.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.negative)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .disabled(!isValid)
                    }
                }
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
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
