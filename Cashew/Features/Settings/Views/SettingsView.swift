import SwiftUI
import StoreKit

struct SettingsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @Environment(\.requestReview) private var requestReview

    @State private var showSignOutError = false
    @State private var signOutErrorMessage = ""
    @State private var showEditProfile = false
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
                Section(
                    header: Text("Notifications"),
                    footer: Text("Event reminders are local notifications. If reminders were created before permission was granted, use Resync Event Reminders.")
                ) {
                    HStack {
                        Label("Status", systemImage: "bell")
                            .foregroundStyle(AppTheme.onSurface)
                        Spacer()
                        Text(container.notificationService.authorizationStatusDescription)
                            .foregroundStyle(container.notificationService.isAuthorized ? .green : .orange)
                    }

                    if container.notificationService.isAuthorized {
                        Button {
                            Task { await scheduleTestNotification() }
                        } label: {
                            settingsRow(icon: "checkmark.seal", color: .green, label: "Send Test Notification (5s)")
                        }

                        Button {
                            Task { await resyncEventReminders() }
                        } label: {
                            settingsRow(icon: "arrow.clockwise", color: .blue, label: "Resync Event Reminders")
                        }
                    } else {
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
                            Text("1.0.0")
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
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
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
        let body = ("App Version: 1.0.0\n\n").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
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
                await container.eventService.refreshNotificationSchedules()
                notificationAlertTitle = "Notifications Enabled"
                notificationAlertMessage = "Event reminders are now enabled and existing reminders were resynced."
            } else {
                notificationAlertTitle = "Notifications Disabled"
                notificationAlertMessage = "Permission was not granted. You can enable notifications in iOS Settings."
            }
            showNotificationAlert = true
            return
        }

        openNotificationSettings()
    }

    private func scheduleTestNotification() async {
        let scheduled = await container.notificationService.scheduleTestNotification(after: 5)
        notificationAlertTitle = scheduled ? "Test Scheduled" : "Unable to Schedule"
        notificationAlertMessage = scheduled
            ? "A test notification should appear in about 5 seconds."
            : "Notifications are not authorized. Enable them in iOS Settings."
        showNotificationAlert = true
    }

    private func resyncEventReminders() async {
        await container.eventService.refreshNotificationSchedules()
        notificationAlertTitle = "Resync Complete"
        notificationAlertMessage = "Event reminders were refreshed."
        showNotificationAlert = true
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
