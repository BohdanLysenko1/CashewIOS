import SwiftUI

struct SettingsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @State private var showSignOutError = false
    @State private var signOutErrorMessage = ""
    @State private var showEditProfile = false
    @State private var showDisableSyncConfirmation = false
    @State private var showSyncDeleteError = false

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    Button {
                        showEditProfile = true
                    } label: {
                        HStack(spacing: 14) {
                            profileAvatar
                            VStack(alignment: .leading, spacing: 2) {
                                Text(container.authService.currentUser?.displayName ?? "")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.onSurface)
                                Text(container.authService.currentUser?.email ?? "")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }
                }

                // Help Section
                Section("Help") {
                    Button {
                        onboardingCoordinator.restart()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.purple.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("Replay Tutorial")
                                .foregroundStyle(AppTheme.onSurface)
                        }
                    }
                }

                // Data Section
                Section(header: Text("Data"), footer: Text("CashewCloud keeps your trips, events, and tasks synced across all your devices. Turning it off stores everything on this device only and removes your data from our servers.")) {
                    HStack {
                        Label("CashewCloud", systemImage: "arrow.triangle.2.circlepath.icloud")
                            .foregroundStyle(AppTheme.onSurface)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { container.dataSyncService.isEnabled },
                            set: { newValue in
                                if !newValue {
                                    showDisableSyncConfirmation = true
                                } else {
                                    container.dataSyncService.isEnabled = true
                                }
                            }
                        ))
                        .labelsHidden()
                    }

                    if !container.dataSyncService.isEnabled {
                        Label("Data is stored on this device only", systemImage: "iphone")
                            .font(.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }

                    if container.dataSyncService.isDeleting {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 6)
                            Text("Deleting server data…")
                                .font(.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }

                // Account Section
                Section {
                    Button(role: .destructive) {
                        signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out Failed", isPresented: $showSignOutError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(signOutErrorMessage)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environment(container)
            }
            .confirmationDialog(
                "Disable Cloud Sync?",
                isPresented: $showDisableSyncConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete from Server & Disable Sync", role: .destructive) {
                    guard let userId = container.authService.currentUser?.id else { return }
                    Task {
                        await container.dataSyncService.disableAndDeleteServerData(userId: userId)
                        if let err = container.dataSyncService.deleteError {
                            signOutErrorMessage = err
                            showSyncDeleteError = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data will be removed from our servers and stored only on this device. This cannot be undone.")
            }
            .alert("Sync Deletion Failed", isPresented: $showSyncDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(signOutErrorMessage)
            }
        }
    }

    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 44, height: 44)
            Text(initials)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let name = container.authService.currentUser?.displayName ?? ""
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func signOut() {
        Task {
            do {
                try await container.authService.signOut()
            } catch {
                signOutErrorMessage = error.localizedDescription
                showSignOutError = true
            }
        }
    }
}


#Preview {
    SettingsView()
        .environment(AppContainer())
        .environment(OnboardingCoordinator())
}
