import SwiftUI

struct EditProfileView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showChangePassword = false

    private var user: AppUser? { container.authService.currentUser }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Avatar
                    HStack {
                        Spacer()
                        avatarView
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                Section("Display Name") {
                    TextField("Your name", text: $displayName)
                        .autocorrectionDisabled()
                }

                Section("Email") {
                    Text(user?.email ?? "")
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }

                Section("Security") {
                    Button("Change Password") {
                        showChangePassword = true
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Profile")
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
                            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onAppear {
                displayName = user?.displayName ?? ""
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
                    .environment(container)
            }
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 72, height: 72)
            Text(initials)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func save() {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await container.authService.updateDisplayName(trimmed)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
