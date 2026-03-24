import SwiftUI

struct PlayerProgressView: View {

    let gamification: GamificationService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                statsRow
                levelRoadmap
                multiplierCard
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("My Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Progress ring + level number
            ZStack {
                // Track
                Circle()
                    .stroke(AppTheme.surfaceContainerHigh, lineWidth: 14)
                    .frame(width: 160, height: 160)

                // Fill
                Circle()
                    .trim(from: 0, to: gamification.levelProgress)
                    .stroke(
                        AppTheme.primaryGradient,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7), value: gamification.levelProgress)

                // Center
                VStack(spacing: 2) {
                    Text("\(gamification.currentLevel)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.onSurface)
                        .monospacedDigit()
                    Text("LEVEL")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .tracking(2)
                }
            }

            // Title + XP
            VStack(spacing: 6) {
                Text(gamification.levelTitle)
                    .font(AppTheme.TextStyle.title)
                    .foregroundStyle(AppTheme.onSurface)

                if gamification.isMaxLevel {
                    Text("Maximum level reached!")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                } else {
                    Text("\(gamification.xpToNextLevel) XP to Level \(gamification.currentLevel + 1)")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(
                value: "\(gamification.totalXP)",
                label: "Total XP",
                icon: "star.fill",
                color: AppTheme.tertiary
            )
            statCell(
                value: "\(Int(gamification.levelProgress * 100))%",
                label: "Level Progress",
                icon: "chart.bar.fill",
                color: AppTheme.primary
            )
            statCell(
                value: gamification.isMaxLevel ? "MAX" : "\(GamificationService.levels.count - gamification.currentLevel)",
                label: gamification.isMaxLevel ? "Level" : "Levels Left",
                icon: "flag.fill",
                color: AppTheme.secondary
            )
        }
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(AppTheme.TextStyle.statMedium)
                .foregroundStyle(AppTheme.onSurface)
            Text(label)
                .font(AppTheme.TextStyle.micro)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Level Roadmap

    private var levelRoadmap: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryGradient)
                Text("Level Roadmap")
                    .font(AppTheme.TextStyle.sectionTitle)
                    .foregroundStyle(AppTheme.onSurface)
            }
            .padding(.horizontal, AppTheme.cardPadding)
            .padding(.top, AppTheme.cardPadding)
            .padding(.bottom, 12)

            ForEach(GamificationService.levels, id: \.level) { entry in
                levelRow(entry: entry)
                if entry.level < GamificationService.levels.count {
                    connectorLine(reached: gamification.totalXP >= entry.xpRequired)
                }
            }
            .padding(.bottom, AppTheme.cardPadding)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private func levelRow(entry: (level: Int, title: String, xpRequired: Int)) -> some View {
        let isReached = gamification.totalXP >= entry.xpRequired
        let isCurrent = entry.level == gamification.currentLevel
        let isNext = entry.level == gamification.currentLevel + 1

        return HStack(spacing: 14) {
            // Circle indicator
            ZStack {
                Circle()
                    .fill(isReached
                          ? LinearGradient(colors: [AppTheme.primary, AppTheme.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [AppTheme.surfaceContainerHigh, AppTheme.surfaceContainerHigh], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)

                if isReached && !isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(entry.level)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isReached ? .white : AppTheme.onSurfaceVariant)
                }
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(isReached ? AppTheme.onSurface : AppTheme.onSurfaceVariant)

                    if isCurrent {
                        Text("CURRENT")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(entry.xpRequired == 0 ? "Starting level" : "\(entry.xpRequired) XP required")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Spacer()

            // Progress bar for current level, lock for future
            if isCurrent && !gamification.isMaxLevel {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(gamification.levelProgress * 100))%")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.primary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppTheme.surfaceContainerHigh)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppTheme.primary)
                                .frame(width: geo.size.width * gamification.levelProgress)
                                .animation(.spring(response: 0.5), value: gamification.levelProgress)
                        }
                    }
                    .frame(width: 60, height: 5)
                }
            } else if isNext {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            } else if !isReached {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 10)
        .background(isCurrent ? AppTheme.primary.opacity(0.06) : Color.clear)
    }

    private func connectorLine(reached: Bool) -> some View {
        Rectangle()
            .fill(reached ? AppTheme.primary.opacity(0.3) : AppTheme.surfaceContainerHigh)
            .frame(width: 2, height: 12)
            .padding(.leading, AppTheme.cardPadding + 17)
    }

    // MARK: - Multiplier Card

    private var multiplierCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.gamificationGradient)
                Text("Streak Multipliers")
                    .font(AppTheme.TextStyle.sectionTitle)
                    .foregroundStyle(AppTheme.onSurface)
            }

            VStack(spacing: 10) {
                multiplierRow(icon: "flame", label: "Default", multiplier: "×1.0", active: true, color: AppTheme.onSurfaceVariant)
                multiplierRow(icon: "flame.fill", label: "7-day streak", multiplier: "×1.5", active: false, color: AppTheme.secondary)
                multiplierRow(icon: "flame.fill", label: "14-day streak", multiplier: "×2.0", active: false, color: AppTheme.tertiary)
            }

            Text("Maintain your daily routines to earn bonus XP on every completed task.")
                .font(AppTheme.TextStyle.caption)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private func multiplierRow(icon: String, label: String, multiplier: String, active: Bool, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(active ? AppTheme.onSurface : AppTheme.onSurfaceVariant)

            Spacer()

            Text(multiplier)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(active ? color : AppTheme.onSurfaceVariant)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(active ? 0.15 : 0.06))
                .clipShape(Capsule())
        }
    }
}
