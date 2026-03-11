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

    /// Which weekday indices (0=Mon … 6=Sun) had at least one event this week
    private var eventDays: Set<Int> {
        let range = thisWeekRange
        let weekEvents = events.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= range.start && day <= range.end
        }
        var days = Set<Int>()
        for event in weekEvents {
            let weekday = calendar.component(.weekday, from: event.date)
            let index = (weekday + 5) % 7 // 0=Mon … 6=Sun
            days.insert(index)
        }
        return days
    }

    // MARK: - Routine Stats

    private var activeRoutines: [DailyRoutine] { routines.filter(\.isEnabled) }
    private var activeRoutineCount: Int { activeRoutines.count }

    // MARK: - Header

    private var weekStartLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: thisWeekRange.start)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                tasksCard
                completionCard
                eventsCard
                routinesCard
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.eventGradient)
                    Text("This Week")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Text("From \(weekStartLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // XP earned badge
            if xpThisWeek > 0 {
                Label("+\(xpThisWeek) XP", systemImage: "star.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Tasks Card

    private var tasksCard: some View {
        StatCard(color: .green) {
            // Icon + trend
            HStack {
                iconBadge("checkmark.circle.fill", color: .green)
                Spacer()
                trendPill(completionTrend)
            }

            // Value
            VStack(alignment: .leading, spacing: 1) {
                Text("\(thisWeekCompleted)")
                    .font(.system(size: 28, weight: .black))
                    .monospacedDigit()
                Text("of \(thisWeekTotal) tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.gradient)
                        .frame(
                            width: thisWeekTotal > 0
                                ? geo.size.width * min(1, Double(thisWeekCompleted) / Double(thisWeekTotal))
                                : 0,
                            height: 5
                        )
                        .animation(.spring(response: 0.5), value: thisWeekCompleted)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Completion Rate Card

    private var completionCard: some View {
        StatCard(color: .blue) {
            HStack {
                iconBadge("target", color: .blue)
                Spacer()
                trendPill(rateTrend)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(Int(thisWeekRate * 100))%")
                    .font(.system(size: 28, weight: .black))
                    .monospacedDigit()
                Text("completion rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Segmented rate bar (10 segments)
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Double(i) / 10.0 < thisWeekRate
                              ? AnyShapeStyle(Color.blue.gradient)
                              : AnyShapeStyle(Color.blue.opacity(0.12)))
                        .frame(height: 5)
                        .animation(.spring(response: 0.4).delay(Double(i) * 0.03), value: thisWeekRate)
                }
            }
        }
    }

    // MARK: - Events Card

    private var eventsCard: some View {
        StatCard(color: .purple) {
            HStack {
                iconBadge("star.fill", color: .purple)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(thisWeekEvents)")
                    .font(.system(size: 28, weight: .black))
                    .monospacedDigit()
                Text("events this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Day dots — Mon through Sun
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(eventDays.contains(i) ? Color.purple : Color.purple.opacity(0.15))
                            .frame(width: 7, height: 7)
                        Text(weekdayLabel(for: i))
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(eventDays.contains(i) ? Color.purple : Color.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Routines Card

    private var routinesCard: some View {
        StatCard(color: .orange) {
            HStack {
                iconBadge("repeat", color: .orange)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(activeRoutineCount)")
                    .font(.system(size: 28, weight: .black))
                    .monospacedDigit()
                Text("active routines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Flame dots per routine (up to 6)
            HStack(spacing: 4) {
                ForEach(Array(activeRoutines.prefix(6).enumerated()), id: \.offset) { _, _ in
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange)
                }
                if activeRoutineCount == 0 {
                    Text("No active routines")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func weekdayLabel(for index: Int) -> String {
        // index 0 = Monday, 6 = Sunday
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        // Calendar weekday: 1=Sun, 2=Mon ... 7=Sat. Map index (0=Mon) to symbol index.
        let calendarIndex = (index + 1) % 7 + 1  // Mon=2, Tue=3 ... Sun=1
        let symbolIndex = calendarIndex - 1
        guard symbolIndex < symbols.count else { return "" }
        return String(symbols[symbolIndex].prefix(1))
    }

    private func iconBadge(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func trendPill(_ trend: Int) -> some View {
        if trend != 0 {
            HStack(spacing: 2) {
                Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8, weight: .bold))
                Text("\(abs(trend))%")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(trend > 0 ? .white : .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(trend > 0 ? Color.green : Color.red)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Stat Card Container

private struct StatCard<Content: View>: View {
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}
