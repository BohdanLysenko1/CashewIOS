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

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // Left: name + location + bars
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text(trip.destination)
                            .font(AppTheme.TextStyle.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        if !daysLabel.isEmpty {
                            Text("· \(daysLabel)")
                                .font(AppTheme.TextStyle.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }
                }

                if !trip.packingItems.isEmpty || !trip.checklistItems.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
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
                    Text("No items added yet")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }

            Spacer(minLength: 0)

            // Right: readiness %
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(Int(overallReadiness * 100))%")
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundStyle(readinessColor)
                    .monospacedDigit()
                Text("ready")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
        .padding(AppTheme.cardPadding)
    }

    private func progressRow(label: String, progress: Double, done: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(AppTheme.TextStyle.caption)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .frame(width: 56, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(barColor(progress).opacity(0.15))
                        .frame(height: 6)

                    // Fill
                    Capsule()
                        .fill(barColor(progress))
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                    // Count badge — floats at the right edge of the fill, clamped so it's always visible
                    let badgeX = min(
                        max(geo.size.width * progress - 14, 0),
                        geo.size.width - 28
                    )
                    Text("\(done)/\(total)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(progress > 0.55 ? .white : barColor(progress))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(progress > 0.55
                                ? barColor(progress)
                                : barColor(progress).opacity(0.15))
                        )
                        .offset(x: badgeX, y: -10)
                }
                .frame(height: 6)
                .padding(.top, 10)
            }
            .frame(height: 26)
        }
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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionHeader(
                    icon: "airplane.circle.fill",
                    title: "Trip Readiness",
                    gradient: AppTheme.tripGradient
                )
                Spacer()
            }
            .padding(AppTheme.cardPadding)

            ForEach(trips) { trip in
                NavigationLink(value: trip.id) {
                    TripReadinessCard(trip: trip)
                }
                .buttonStyle(.plain)
            }
        }
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
