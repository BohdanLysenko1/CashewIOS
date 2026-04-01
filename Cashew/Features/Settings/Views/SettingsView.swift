import SwiftUI
import StoreKit

struct SettingsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @Environment(\.requestReview) private var requestReview

    @State private var showSignOutError = false
    @State private var signOutErrorMessage = ""
    @State private var showProfile = false
    @State private var showWhatsNew = false
    @State private var showDisableSyncConfirmation = false
    @State private var showSyncDeleteError = false
    @State private var syncDeleteErrorMessage = ""
    @State private var showNotificationAlert = false
    @State private var notificationAlertTitle = ""
    @State private var notificationAlertMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    Button {
                        showProfile = true
                    } label: {
                        HStack(spacing: 14) {
                            UserAvatarView(
                                displayName: profileName,
                                avatarPath: container.authService.currentUser?.avatarPath,
                                size: 52,
                                tint: .blue
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(profileName)
                                    .font(AppTheme.TextStyle.sectionTitle)
                                    .foregroundStyle(AppTheme.onSurface)

                                Text(profileEmail)
                                    .font(AppTheme.TextStyle.secondary)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                                    .lineLimit(1)

                                Text("Manage profile")
                                    .font(AppTheme.TextStyle.captionBold)
                                    .foregroundStyle(AppTheme.primary)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                                .frame(width: 26, height: 26)
                                .background(AppTheme.surfaceContainerLow, in: Circle())
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Help Section
                Section("Help") {
                    Button {
                        onboardingCoordinator.restart()
                    } label: {
                        settingsRow(icon: "questionmark.circle", color: .purple, label: "Replay Tutorial")
                    }

                    Button {
                        sendFeedback()
                    } label: {
                        settingsRow(icon: "envelope", color: .blue, label: "Send Feedback")
                    }

                    Button {
                        requestReview()
                    } label: {
                        settingsRow(icon: "star", color: .yellow, label: "Rate Cashew")
                    }
                }

                // Notifications Section
                Section("Notifications") {
                    NavigationLink {
                        NotificationPreferencesView()
                            .environment(container)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.indigo.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("Notification Preferences")
                                .foregroundStyle(AppTheme.onSurface)

                            Spacer()

                            Text(container.notificationService.isAuthorized ? "On" : "Off")
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }

                    if !container.notificationService.isAuthorized {
                        Button {
                            Task { await enableNotifications() }
                        } label: {
                            settingsRow(
                                icon: container.notificationService.canRequestAuthorization ? "bell.badge" : "gearshape",
                                color: container.notificationService.canRequestAuthorization ? .indigo : .orange,
                                label: container.notificationService.canRequestAuthorization ? "Enable Notifications" : "Open iOS Notification Settings"
                            )
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
                    Button {
                        showWhatsNew = true
                    } label: {
                        HStack {
                            Label("Version", systemImage: "info.circle")
                                .foregroundStyle(AppTheme.onSurface)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environment(container)
            }
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView()
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
                            syncDeleteErrorMessage = err
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
                Text(syncDeleteErrorMessage)
            }
            .alert(notificationAlertTitle, isPresented: $showNotificationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(notificationAlertMessage)
            }
            .task {
                await container.notificationService.checkAuthorizationStatus()
            }
        }
    }

    private var profileName: String {
        let name = container.authService.currentUser?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Bodo" : name
    }

    private var profileEmail: String {
        container.authService.currentUser?.email ?? "No email"
    }

    // MARK: - Helpers

    private func settingsRow(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(label)
                .foregroundStyle(AppTheme.onSurface)
        }
    }

    private func sendFeedback() {
        let subject = "Cashew Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let body = ("App Version: \(version)\n\n").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:cashew@cashewplanner.com?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(url)
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

    private func enableNotifications() async {
        if container.notificationService.canRequestAuthorization {
            _ = await container.requestNotificationPermission()
            await container.notificationService.checkAuthorizationStatus()
            let granted = container.notificationService.isAuthorized

            if granted {
                await container.notificationScheduler.rescheduleAll(
                    events: container.eventService.events,
                    tasks: container.dayPlannerService.allTasks,
                    routines: container.dayPlannerService.routines,
                    trips: container.tripService.trips,
                    gamificationService: container.gamificationService
                )
                notificationAlertTitle = "Notifications Enabled"
                notificationAlertMessage = "All reminders are now enabled and synced."
            } else {
                notificationAlertTitle = "Notifications Disabled"
                notificationAlertMessage = "Permission was not granted. You can enable notifications in iOS Settings."
            }
            showNotificationAlert = true
            return
        }

        openNotificationSettings()
    }

private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}


#Preview {
    SettingsView()
        .environment(AppContainer())
        .environment(OnboardingCoordinator())
}
