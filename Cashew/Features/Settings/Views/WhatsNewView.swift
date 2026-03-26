import SwiftUI

struct WhatsNewView: View {

    @Environment(\.dismiss) private var dismiss

    private let features: [Feature] = [
        Feature(icon: "sun.max.fill",                    color: .orange, title: "Your Day at a Glance",   detail: "Daily tasks, habits, a scheduler, and an XP system that makes getting things done actually rewarding."),
        Feature(icon: "airplane.circle.fill",            color: .blue,   title: "Trip Planning",           detail: "Budget tracking, packing lists, itinerary, accommodation, and transport — everything for a trip in one place."),
        Feature(icon: "star.circle.fill",                color: .pink,   title: "Events & Reminders",      detail: "One-off and recurring events with priorities, costs, and custom reminders."),
        Feature(icon: "calendar.circle.fill",            color: .purple, title: "Unified Calendar",        detail: "See trips, events, and tasks together. Filter by category and collapse to a week strip."),
        Feature(icon: "arrow.triangle.2.circlepath.icloud", color: .teal, title: "CashewCloud Sync",      detail: "Your data synced across all your devices instantly. Turn it off anytime to go local-only."),
        Feature(icon: "person.2.fill",                   color: .green,  title: "Trip Sharing",            detail: "Invite friends to collaborate on a trip and plan together in real time."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader

                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            FeatureRow(feature: feature)
                            if index < features.count - 1 {
                                Divider()
                                    .padding(.leading, 84)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
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

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - Supporting Types

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
