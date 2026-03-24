import SwiftUI

struct SettingsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @State private var showSignOutError = false
    @State private var signOutErrorMessage = ""
    @State private var isCheckingCloud = false
    @State private var showCloudUnavailableAlert = false
    @State private var showEditProfile = false

    var body: some View {
        @Bindable var syncService = container.syncService

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

                // Cloud Section
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "icloud")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { frame in
                                onboardingCoordinator.registerFrame(
                                    id: "anchor_settings_icloud",
                                    frame: frame
                                )
                            }

                        Toggle("iCloud Sync", isOn: $syncService.isSyncEnabled)
                            .disabled(isCheckingCloud)
                            .onChange(of: syncService.isSyncEnabled) { _, newValue in
                                if newValue {
                                    checkCloudAvailability()
                                }
                            }
                    }

                    if syncService.isSyncEnabled {
                        HStack {
                            Text("Status")
                            Spacer()
                            SyncStatusView(status: syncService.syncStatus)
                        }

                        if let lastSync = syncService.lastSyncDate {
                            HStack {
                                Text("Last Sync")
                                Spacer()
                                Text(lastSync, style: .relative)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                            }
                        }

                        Button {
                            Task { await container.syncService.sync() }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                        .disabled(syncService.syncStatus == .syncing)
                    }
                } header: {
                    Text("Cloud")
                } footer: {
                    Text("Sync your trips and events across all your devices using iCloud.")
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
            .alert("iCloud Unavailable", isPresented: $showCloudUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please sign in to iCloud in Settings to enable sync.")
            }
            .alert("Sign Out Failed", isPresented: $showSignOutError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(signOutErrorMessage)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environment(container)
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

    private func checkCloudAvailability() {
        isCheckingCloud = true
        Task {
            let available = await container.syncService.checkCloudAvailability()
            isCheckingCloud = false

            if !available {
                container.syncService.isSyncEnabled = false
                showCloudUnavailableAlert = true
            }
        }
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

// MARK: - Sync Status View

private struct SyncStatusView: View {
    let status: SyncStatus

    var body: some View {
        switch status {
        case .idle:
            Text("Idle")
                .foregroundStyle(AppTheme.onSurfaceVariant)
        case .syncing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
            }
            .foregroundStyle(AppTheme.onSurfaceVariant)
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Synced")
            }
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Failed")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppContainer())
        .environment(OnboardingCoordinator())
}
