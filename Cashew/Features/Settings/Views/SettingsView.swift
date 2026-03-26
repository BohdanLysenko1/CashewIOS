import SwiftUI

struct SettingsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @State private var showSignOutError = false
    @State private var signOutErrorMessage = ""
    @State private var showEditProfile = false

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
