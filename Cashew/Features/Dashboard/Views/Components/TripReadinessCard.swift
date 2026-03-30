import SwiftUI

struct TripReadinessCard: View {

    let trip: Trip

    private var packingPacked: Int { trip.packingItems.filter { $0.isPacked }.count }
    private var checklistDone: Int { trip.checklistItems.filter { $0.isCompleted }.count }

    private var overallReadiness: Double {
        let hasPacking = !trip.packingItems.isEmpty
        let hasChecklist = !trip.checklistItems.isEmpty
        if !hasPacking && !hasChecklist { return 1.0 }
        if !hasPacking { return trip.checklistProgress }
        if !hasChecklist { return trip.packingProgress }
        return (trip.packingProgress + trip.checklistProgress) / 2.0
    }

    private var readinessColor: Color {
        if overallReadiness >= 0.75 { return .green }
        if overallReadiness >= 0.4 { return .orange }
        return .red
    }

    private var daysLabel: String {
        guard let days = trip.daysUntilTrip else { return "" }
        if days < 0 { return "In progress" }
        if days == 0 { return "Today!" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days away"
    }

    private var readinessLabel: String {
        if overallReadiness >= 0.75 { return "Strong" }
        if overallReadiness >= 0.4 { return "On Track" }
        return "Needs Focus"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text(trip.destination)
                            .font(AppTheme.TextStyle.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(overallReadiness * 100))%")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(readinessColor)
                        .monospacedDigit()
                    Text(readinessLabel)
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }

            HStack(spacing: 8) {
                if !daysLabel.isEmpty {
                    metaChip(icon: "calendar", label: daysLabel)
                }
                if trip.tripDuration > 0 {
                    metaChip(
                        icon: "clock",
                        label: "\(trip.tripDuration) day\(trip.tripDuration == 1 ? "" : "s")"
                    )
                }
            }

            if !trip.packingItems.isEmpty || !trip.checklistItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if !trip.packingItems.isEmpty {
                        progressRow(
                            label: "Packing",
                            progress: trip.packingProgress,
                            done: packingPacked,
                            total: trip.packingItems.count
                        )
                    }
                    if !trip.checklistItems.isEmpty {
                        progressRow(
                            label: "Checklist",
                            progress: trip.checklistProgress,
                            done: checklistDone,
                            total: trip.checklistItems.count
                        )
                    }
                }
            } else {
                Text("No packing or checklist items yet.")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
        .padding(14)
        .background(AppTheme.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
    }

    private func progressRow(label: String, progress: Double, done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                Spacer()
                Text("\(done)/\(total)")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurface)
            }
            AppProgressBar(progress: progress, color: barColor(progress))
                .frame(height: AppTheme.progressBarHeight)
        }
    }

    private func metaChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(AppTheme.TextStyle.caption)
        }
        .foregroundStyle(AppTheme.onSurfaceVariant)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.surfaceContainer)
        .clipShape(Capsule())
    }

    private func barColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Section

struct TripReadinessSection: View {

    let trips: [Trip]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(
                    icon: "airplane.circle.fill",
                    title: "Trip Readiness",
                    gradient: AppTheme.tripGradient
                )
                Spacer()
                Text("\(trips.count)")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppTheme.cardPadding)
            .padding(.top, AppTheme.cardPadding)

            ForEach(trips) { trip in
                NavigationLink(value: trip.id) {
                    TripReadinessCard(trip: trip)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppTheme.cardPadding)
            }
        }
        .padding(.bottom, AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(
            color: AppTheme.cardShadow,
            radius: AppTheme.cardShadowRadius,
            x: 0,
            y: AppTheme.cardShadowY
        )
    }
}
