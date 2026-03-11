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
        .background(Color(.systemGroupedBackground))
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
                    .stroke(Color(.systemGray5), lineWidth: 14)
                    .frame(width: 160, height: 160)

                // Fill
                Circle()
                    .trim(from: 0, to: gamification.levelProgress)
                    .stroke(
                        LinearGradient(
                            colors: [Color("AccentColor"), Color("AccentColor").opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7), value: gamification.levelProgress)

                // Center
                VStack(spacing: 2) {
                    Text("\(gamification.currentLevel)")
                        .font(.system(size: 48, weight: .black))
                        .monospacedDigit()
                    Text("LEVEL")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(2)
                }
            }

            // Title + XP
            VStack(spacing: 6) {
                Text(gamification.levelTitle)
                    .font(.title2)
                    .fontWeight(.bold)

                if gamification.isMaxLevel {
                    Text("Maximum level reached!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(gamification.xpToNextLevel) XP to Level \(gamification.currentLevel + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(
                value: "\(gamification.totalXP)",
                label: "Total XP",
                icon: "star.fill",
                color: .orange
            )
            statCell(
                value: "\(Int(gamification.levelProgress * 100))%",
                label: "Level Progress",
                icon: "chart.bar.fill",
                color: Color("AccentColor")
            )
            statCell(
                value: gamification.isMaxLevel ? "MAX" : "\(GamificationService.levels.count - gamification.currentLevel)",
                label: gamification.isMaxLevel ? "Level" : "Levels Left",
                icon: "flag.fill",
                color: .green
            )
        }
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.black)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Level Roadmap

    private var levelRoadmap: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color("AccentColor"))
                Text("Level Roadmap")
                    .font(.headline)
                    .fontWeight(.bold)
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
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
                          ? LinearGradient(colors: [Color("AccentColor"), Color("AccentColor").opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)

                if isReached && !isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(entry.level)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isReached ? .white : .secondary)
                }
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(.subheadline)
                        .fontWeight(isCurrent ? .bold : .medium)
                        .foregroundStyle(isReached ? .primary : .secondary)

                    if isCurrent {
                        Text("CURRENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color("AccentColor"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("AccentColor").opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(entry.xpRequired == 0 ? "Starting level" : "\(entry.xpRequired) XP required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Progress bar for current level, lock for future
            if isCurrent && !gamification.isMaxLevel {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(gamification.levelProgress * 100))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color("AccentColor"))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color("AccentColor"))
                                .frame(width: geo.size.width * gamification.levelProgress)
                                .animation(.spring(response: 0.5), value: gamification.levelProgress)
                        }
                    }
                    .frame(width: 60, height: 5)
                }
            } else if isNext {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if !isReached {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 10)
        .background(isCurrent ? Color("AccentColor").opacity(0.06) : Color.clear)
    }

    private func connectorLine(reached: Bool) -> some View {
        Rectangle()
            .fill(reached ? Color("AccentColor").opacity(0.3) : Color(.systemGray5))
            .frame(width: 2, height: 12)
            .padding(.leading, AppTheme.cardPadding + 17)
    }

    // MARK: - Multiplier Card

    private var multiplierCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.yellow)
                Text("Streak Multipliers")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            VStack(spacing: 10) {
                multiplierRow(icon: "flame", label: "Default", multiplier: "×1.0", active: true, color: .secondary)
                multiplierRow(icon: "flame.fill", label: "7-day streak", multiplier: "×1.5", active: false, color: .orange)
                multiplierRow(icon: "flame.fill", label: "14-day streak", multiplier: "×2.0", active: false, color: .red)
            }

            Text("Maintain your daily routines to earn bonus XP on every completed task.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppTheme.cardPadding)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private func multiplierRow(icon: String, label: String, multiplier: String, active: Bool, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(active ? .primary : .secondary)

            Spacer()

            Text(multiplier)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(active ? color : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(active ? 0.15 : 0.06))
                .clipShape(Capsule())
        }
    }
}
