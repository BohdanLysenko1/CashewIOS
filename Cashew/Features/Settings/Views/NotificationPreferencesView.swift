import SwiftUI

struct NotificationPreferencesView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var morningBriefingEnabled = NotificationPreferences.morningBriefingEnabled
    @State private var morningBriefingTime = Self.timeFromComponents(
        hour: NotificationPreferences.morningBriefingHour,
        minute: NotificationPreferences.morningBriefingMinute
    )
    @State private var eveningWrapUpEnabled = NotificationPreferences.eveningWrapUpEnabled
    @State private var eveningWrapUpTime = Self.timeFromComponents(
        hour: NotificationPreferences.eveningWrapUpHour,
        minute: NotificationPreferences.eveningWrapUpMinute
    )
    @State private var taskRemindersEnabled = NotificationPreferences.taskRemindersEnabled
    @State private var taskReminderLeadMinutes = NotificationPreferences.taskReminderLeadMinutes
    @State private var routineNudgesEnabled = NotificationPreferences.routineNudgesEnabled
    @State private var tripCountdownEnabled = NotificationPreferences.tripCountdownEnabled
    @State private var streakProtectionEnabled = NotificationPreferences.streakProtectionEnabled
    @State private var streakProtectionTime = Self.timeFromComponents(
        hour: NotificationPreferences.streakProtectionHour,
        minute: NotificationPreferences.streakProtectionMinute
    )
    @State private var levelUpEnabled = NotificationPreferences.levelUpEnabled

    @State private var showTestAlert = false
    @State private var testAlertTitle = ""
    @State private var testAlertMessage = ""

    var body: some View {
        List {
            // Daily Briefings
            Section(
                header: Text("Daily Briefings"),
                footer: Text("Get a summary of your day each morning and a wrap-up each evening.")
            ) {
                Toggle("Morning Briefing", isOn: $morningBriefingEnabled)
                if morningBriefingEnabled {
                    DatePicker("Time", selection: $morningBriefingTime, displayedComponents: .hourAndMinute)
                }

                Toggle("Evening Wrap-up", isOn: $eveningWrapUpEnabled)
                if eveningWrapUpEnabled {
                    DatePicker("Time", selection: $eveningWrapUpTime, displayedComponents: .hourAndMinute)
                }
            }

            // Tasks & Routines
            Section(
                header: Text("Tasks & Routines"),
                footer: Text("Get reminded before scheduled tasks start and when it's time for your routines.")
            ) {
                Toggle("Task Reminders", isOn: $taskRemindersEnabled)
                if taskRemindersEnabled {
                    Picker("Lead Time", selection: $taskReminderLeadMinutes) {
                        ForEach(NotificationPreferences.availableLeadMinutes, id: \.self) { minutes in
                            Text(leadTimeLabel(minutes)).tag(minutes)
                        }
                    }
                }

                Toggle("Routine Reminders", isOn: $routineNudgesEnabled)
            }

            // Trips
            Section(
                header: Text("Trips"),
                footer: Text("Countdown notifications at 7, 3, and 1 day before your trip, plus packing reminders.")
            ) {
                Toggle("Trip Countdowns", isOn: $tripCountdownEnabled)
            }

            // Streaks & Gamification
            Section(
                header: Text("Motivation"),
                footer: Text("Protect your streaks with an evening reminder and celebrate when you level up.")
            ) {
                Toggle("Streak Protection", isOn: $streakProtectionEnabled)
                if streakProtectionEnabled {
                    DatePicker("Alert Time", selection: $streakProtectionTime, displayedComponents: .hourAndMinute)
                }

                Toggle("Level-up Celebrations", isOn: $levelUpEnabled)
            }

            // Actions
            Section {
                Button {
                    Task { await sendTestNotification() }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.positive, AppTheme.positive.opacity(0.72)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("Send Test Notification (5s)")
                            .foregroundStyle(AppTheme.onSurface)
                    }
                }

                Button {
                    Task { await resyncAll() }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("Resync All Notifications")
                            .foregroundStyle(AppTheme.onSurface)
                    }
                }

                HStack {
                    Label("Status", systemImage: "bell")
                        .foregroundStyle(AppTheme.onSurface)
                    Spacer()
                    Text(container.notificationService.authorizationStatusDescription)
                        .foregroundStyle(container.notificationService.isAuthorized ? AppTheme.positive : AppTheme.warning)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: morningBriefingEnabled) { _, val in NotificationPreferences.morningBriefingEnabled = val; scheduleRefresh() }
        .onChange(of: morningBriefingTime) { _, val in
            saveTime(val, setHour: { NotificationPreferences.morningBriefingHour = $0 }, setMinute: { NotificationPreferences.morningBriefingMinute = $0 })
            scheduleRefresh()
        }
        .onChange(of: eveningWrapUpEnabled) { _, val in NotificationPreferences.eveningWrapUpEnabled = val; scheduleRefresh() }
        .onChange(of: eveningWrapUpTime) { _, val in
            saveTime(val, setHour: { NotificationPreferences.eveningWrapUpHour = $0 }, setMinute: { NotificationPreferences.eveningWrapUpMinute = $0 })
            scheduleRefresh()
        }
        .onChange(of: taskRemindersEnabled) { _, val in NotificationPreferences.taskRemindersEnabled = val; scheduleRefresh() }
        .onChange(of: taskReminderLeadMinutes) { _, val in NotificationPreferences.taskReminderLeadMinutes = val; scheduleRefresh() }
        .onChange(of: routineNudgesEnabled) { _, val in NotificationPreferences.routineNudgesEnabled = val; scheduleRefresh() }
        .onChange(of: tripCountdownEnabled) { _, val in NotificationPreferences.tripCountdownEnabled = val; scheduleRefresh() }
        .onChange(of: streakProtectionEnabled) { _, val in NotificationPreferences.streakProtectionEnabled = val; scheduleRefresh() }
        .onChange(of: streakProtectionTime) { _, val in
            saveTime(val, setHour: { NotificationPreferences.streakProtectionHour = $0 }, setMinute: { NotificationPreferences.streakProtectionMinute = $0 })
            scheduleRefresh()
        }
        .onChange(of: levelUpEnabled) { _, val in NotificationPreferences.levelUpEnabled = val }
        .alert(testAlertTitle, isPresented: $showTestAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(testAlertMessage)
        }
        .task {
            await container.notificationService.checkAuthorizationStatus()
        }
    }

    // MARK: - Helpers

    private func leadTimeLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min before"
        }
        return "\(minutes / 60) hour before"
    }

    private static func timeFromComponents(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func saveTime(_ date: Date, setHour: (Int) -> Void, setMinute: (Int) -> Void) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        setHour(components.hour ?? 8)
        setMinute(components.minute ?? 0)
    }

    private func scheduleRefresh() {
        Task {
            await container.notificationScheduler.rescheduleAll(
                events: container.eventService.events,
                tasks: container.dayPlannerService.allTasks,
                routines: container.dayPlannerService.routines,
                trips: container.tripService.trips,
                gamificationService: container.gamificationService
            )
        }
    }

    private func sendTestNotification() async {
        let success = await container.notificationService.scheduleTestNotification(after: 5)
        testAlertTitle = success ? "Test Scheduled" : "Unable to Schedule"
        testAlertMessage = success
            ? "A test notification should appear in about 5 seconds."
            : "Notifications are not authorized. Enable them in iOS Settings."
        showTestAlert = true
    }

    private func resyncAll() async {
        await container.notificationScheduler.rescheduleAll(
            events: container.eventService.events,
            tasks: container.dayPlannerService.allTasks,
            routines: container.dayPlannerService.routines,
            trips: container.tripService.trips,
            gamificationService: container.gamificationService
        )
        testAlertTitle = "Resync Complete"
        testAlertMessage = "All notifications have been refreshed."
        showTestAlert = true
    }
}
