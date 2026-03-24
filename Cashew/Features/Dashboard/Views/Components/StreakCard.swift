import SwiftUI

struct StreakCard: View {

    let routine: DailyRoutine
    let currentStreak: Int
    let bestStreak: Int

    private var flameColor: Color {
        switch currentStreak {
        case 30...: return .yellow
        case 14...: return .purple
        case 7...: return .red
        case 3...: return .orange
        default: return .gray
        }
    }

    private var flameSize: CGFloat {
        switch currentStreak {
        case 30...: return 32
        case 14...: return 28
        case 7...: return 26
        case 3...: return 24
        default: return 20
        }
    }

    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 10) {
            // Flame + streak count
            ZStack {
                // Pulsing glow ring — only for active streaks
                if currentStreak >= 3 {
                    Circle()
                        .stroke(flameColor.opacity(0.35), lineWidth: 2.5)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulsing ? 1.45 : 1.0)
                        .opacity(pulsing ? 0 : 1)
                        .animation(
                            .easeOut(duration: AppTheme.pulseRingDuration).repeatForever(autoreverses: false),
                            value: pulsing
                        )
                }

                Circle()
                    .fill(flameColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: currentStreak >= 3 ? "flame.fill" : "flame")
                    .font(.system(size: flameSize))
                    .foregroundStyle(flameColor.gradient)
                    .symbolEffect(.bounce, value: currentStreak)
                    .symbolEffect(.pulse, isActive: currentStreak >= 7)
            }
            .onAppear {
                if currentStreak >= 3 { pulsing = true }
            }

            // Streak number
            Text("\(currentStreak)")
                .font(AppTheme.TextStyle.statMedium)
                .foregroundStyle(AppTheme.onSurface)

            // Routine name
            Text(routine.title)
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.onSurface)
                .lineLimit(1)
                .truncationMode(.tail)

            // Best streak
            if bestStreak > 0 {
                Text("Best: \(bestStreak)")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
        .frame(width: 110)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(AppTheme.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
    }
}

struct StreakTrackerSection: View {

    let routines: [DailyRoutine]
    let allTasks: [DailyTask]

    private var streakData: [(routine: DailyRoutine, current: Int, best: Int)] {
        routines
            .filter(\.isEnabled)
            .map { routine in
                let (current, best) = computeStreak(for: routine)
                return (routine, current, best)
            }
            .sorted { $0.current > $1.current }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.gamificationGradient)
                Text("Streaks")
                    .font(AppTheme.TextStyle.sectionTitle)
                    .foregroundStyle(AppTheme.onSurface)

                Spacer()

                if let topStreak = streakData.first, topStreak.current >= 3 {
                    Text("\(topStreak.current) day best!")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.tertiary)
                }
            }

            if streakData.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "repeat")
                        .font(.title2)
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No active routines")
                            .font(AppTheme.TextStyle.bodyBold)
                            .foregroundStyle(AppTheme.onSurface)
                        Text("Create routines in My Day to track streaks")
                            .font(AppTheme.TextStyle.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(streakData, id: \.routine.id) { data in
                            StreakCard(
                                routine: data.routine,
                                currentStreak: data.current,
                                bestStreak: data.best
                            )
                        }
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Streak Computation

    private func computeStreak(for routine: DailyRoutine) -> (current: Int, best: Int) {
        StreakCalculator.streaks(for: routine, tasks: allTasks)
    }
}
