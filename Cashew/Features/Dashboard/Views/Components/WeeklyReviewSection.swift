import SwiftUI

struct WeeklyReviewSection: View {

    let allTasks: [DailyTask]
    let events: [Event]
    let routines: [DailyRoutine]

    private var calendar: Calendar { Calendar.current }

    // MARK: - Week Ranges

    private var thisWeekRange: (start: Date, end: Date) {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today),
              let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else {
            return (today, today)
        }
        return (monday, sunday)
    }

    private var lastWeekRange: (start: Date, end: Date) {
        let thisWeek = thisWeekRange
        guard let monday = calendar.date(byAdding: .day, value: -7, to: thisWeek.start),
              let sunday = calendar.date(byAdding: .day, value: -1, to: thisWeek.start) else {
            return (thisWeek.start, thisWeek.start)
        }
        return (monday, sunday)
    }

    // MARK: - Task Stats

    private func tasksInRange(_ range: (start: Date, end: Date)) -> [DailyTask] {
        allTasks.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= range.start && day <= range.end
        }
    }

    private var thisWeekTasks: [DailyTask] { tasksInRange(thisWeekRange) }
    private var lastWeekTasks: [DailyTask] { tasksInRange(lastWeekRange) }

    private var thisWeekCompleted: Int { thisWeekTasks.filter(\.isCompleted).count }
    private var lastWeekCompleted: Int { lastWeekTasks.filter(\.isCompleted).count }
    private var thisWeekTotal: Int { thisWeekTasks.count }
    private var lastWeekTotal: Int { lastWeekTasks.count }

    private var thisWeekRate: Double {
        guard thisWeekTotal > 0 else { return 0 }
        return Double(thisWeekCompleted) / Double(thisWeekTotal)
    }

    private var lastWeekRate: Double {
        guard lastWeekTotal > 0 else { return 0 }
        return Double(lastWeekCompleted) / Double(lastWeekTotal)
    }

    private var completionTrend: Int {
        guard lastWeekCompleted > 0 else { return thisWeekCompleted > 0 ? 100 : 0 }
        return Int(((Double(thisWeekCompleted) - Double(lastWeekCompleted)) / Double(lastWeekCompleted)) * 100)
    }

    private var rateTrend: Int {
        guard lastWeekRate > 0 else { return thisWeekRate > 0 ? 100 : 0 }
        return Int(((thisWeekRate - lastWeekRate) / lastWeekRate) * 100)
    }

    // MARK: - XP This Week

    private var xpThisWeek: Int {
        thisWeekTasks
            .filter(\.isCompleted)
            .reduce(0) { $0 + XPCalculator.xp(for: $1) }
    }

    // MARK: - Event Stats

    private var thisWeekEvents: Int {
        let range = thisWeekRange
        return events.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= range.start && day <= range.end
        }.count
    }

    // MARK: - Routine Stats

    private var activeRoutineCount: Int { routines.filter(\.isEnabled).count }

    // MARK: - Header

    private var weekStartLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: thisWeekRange.start)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionHeader(icon: "chart.line.uptrend.xyaxis", title: "This Week", gradient: AppTheme.dayPlannerGradient)
                    Text("From \(weekStartLabel)")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }

                Spacer()

                if xpThisWeek > 0 {
                    Label("+\(xpThisWeek) XP", systemImage: "star.fill")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.tertiary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(AppTheme.cardPadding)

            // Rows (whitespace separation, no dividers)
            statRow(
                label: "Tasks completed",
                value: "\(thisWeekCompleted) / \(thisWeekTotal)",
                trend: completionTrend,
                showProgress: true,
                progress: thisWeekTotal > 0 ? Double(thisWeekCompleted) / Double(thisWeekTotal) : 0
            )

            statRow(
                label: "Completion rate",
                value: "\(Int(thisWeekRate * 100))%",
                trend: rateTrend,
                showProgress: false,
                progress: 0
            )

            statRow(
                label: "Events",
                value: "\(thisWeekEvents)",
                trend: nil,
                showProgress: false,
                progress: 0
            )

            statRow(
                label: "Active routines",
                value: "\(activeRoutineCount)",
                trend: nil,
                showProgress: false,
                progress: 0
            )
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Row

    private func statRow(label: String, value: String, trend: Int?, showProgress: Bool, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(AppTheme.TextStyle.body)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                Spacer()

                HStack(spacing: 6) {
                    Text(value)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                        .monospacedDigit()

                    if let trend, trend != 0 {
                        trendPill(trend)
                    }
                }
            }

            if showProgress {
                AppProgressBar(progress: progress, color: AppTheme.primary)
            }
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 13)
    }

    // MARK: - Trend Pill

    @ViewBuilder
    private func trendPill(_ trend: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8, weight: .bold))
            Text("\(abs(trend))%")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(trend > 0 ? AppTheme.positive : AppTheme.negative)
        .clipShape(Capsule())
    }
}
