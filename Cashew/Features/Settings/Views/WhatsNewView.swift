import SwiftUI

struct WhatsNewView: View {

    @Environment(\.dismiss) private var dismiss

    private let releases: [Release] = [
        Release(version: "1.1", features: [
            Feature(icon: "bell.badge.fill",                    color: .indigo, title: "Smart Notifications",      detail: "Morning briefings, task reminders, routine nudges, trip countdowns, streak protection, and level-up celebrations — all within a smart 64-notification budget."),
            Feature(icon: "paintbrush.fill",                    color: .mint,   title: "Redesigned Experience",    detail: "Refreshed app design with a cleaner dashboard, improved event creation flow, and a polished settings screen."),
            Feature(icon: "hand.tap.fill",                      color: .orange, title: "Interactive Actions",      detail: "Mark tasks complete or snooze reminders right from the notification — no need to open the app."),
            Feature(icon: "person.crop.circle.badge.checkmark", color: .blue,   title: "Profile Persistence",     detail: "Your username, avatar, and email now sync reliably across sign-outs and sign-ins."),
            Feature(icon: "gearshape.2.fill",                   color: .purple, title: "Notification Preferences", detail: "Fine-tune every notification type — set custom times for briefings, choose lead times for task reminders, and toggle each category independently."),
            Feature(icon: "person.2.fill",                      color: .green,  title: "Improved Sharing",        detail: "Real-time trip collaboration is more reliable with better avatar display and collaborator management."),
        ]),
        Release(version: "1.0", features: [
            Feature(icon: "sun.max.fill",                          color: .orange, title: "Your Day at a Glance", detail: "Daily tasks, habits, a scheduler, and an XP system that makes getting things done actually rewarding."),
            Feature(icon: "airplane.circle.fill",                  color: .blue,   title: "Trip Planning",         detail: "Budget tracking, packing lists, itinerary, accommodation, and transport — everything for a trip in one place."),
            Feature(icon: "star.circle.fill",                      color: .pink,   title: "Events & Reminders",    detail: "One-off and recurring events with priorities, costs, and custom reminders."),
            Feature(icon: "calendar.circle.fill",                  color: .purple, title: "Unified Calendar",      detail: "See trips, events, and tasks together. Filter by category and collapse to a week strip."),
            Feature(icon: "arrow.triangle.2.circlepath.icloud",    color: .teal,   title: "CashewCloud Sync",     detail: "Your data synced across all your devices instantly. Turn it off anytime to go local-only."),
            Feature(icon: "person.2.fill",                         color: .green,  title: "Trip Sharing",          detail: "Invite friends to collaborate on a trip and plan together in real time."),
        ]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader

                    ForEach(Array(releases.enumerated()), id: \.offset) { index, release in
                        if index > 0 {
                            Divider()
                                .padding(.horizontal)
                                .padding(.top, 16)
                        }

                        versionHeader(release.version, isLatest: index == 0)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(release.features.enumerated()), id: \.offset) { fIndex, feature in
                                FeatureRow(feature: feature)
                                if fIndex < release.features.count - 1 {
                                    Divider()
                                        .padding(.leading, 84)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.tripGradient)
                .padding(.top, 8)

            Text("What's New in Cashew")
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func versionHeader(_ version: String, isLatest: Bool) -> some View {
        HStack(spacing: 8) {
            Text("Version \(version)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.onSurface)

            if isLatest {
                Text("Latest")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppTheme.primary, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
}

// MARK: - Supporting Types

private struct Release {
    let version: String
    let features: [Feature]
}

private struct Feature {
    let icon: String
    let color: Color
    let title: String
    let detail: String
}

private struct FeatureRow: View {
    let feature: Feature

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.icon)
                .font(.system(size: 28))
                .foregroundStyle(feature.color.gradient)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.onSurface)

                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

#Preview {
    WhatsNewView()
}
