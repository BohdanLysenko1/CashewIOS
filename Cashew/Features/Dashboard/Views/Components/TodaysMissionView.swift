import SwiftUI

struct TodaysMissionView: View {

    let tasks: [DailyTask]
    let onAddTask: () -> Void

    // MARK: - Computed

    private var completedCount: Int { tasks.filter(\.isCompleted).count }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(tasks.count)
    }

    private var isAllDone: Bool { !tasks.isEmpty && completedCount == tasks.count }

    private var potentialXP: Int {
        tasks.reduce(0) { $0 + XPCalculator.xp(for: $1) } + XPCalculator.dayCompletionBonus
    }

    private var earnedXP: Int {
        let base = tasks.filter(\.isCompleted).reduce(0) { $0 + XPCalculator.xp(for: $1) }
        let bonus = isAllDone ? XPCalculator.dayCompletionBonus : 0
        return base + bonus
    }

    private var headlineText: String {
        if tasks.isEmpty { return "No mission yet" }
        if isAllDone { return "Mission complete!" }
        let remaining = tasks.count - completedCount
        if completedCount == 0 { return "Ready to crush it?" }
        return "\(remaining) task\(remaining == 1 ? "" : "s") to go"
    }

    private var subtitleText: String {
        if tasks.isEmpty { return "Add tasks to plan your day" }
        if isAllDone { return "You earned \(earnedXP) XP today!" }
        if completedCount == 0 { return "Earn up to \(potentialXP) XP today" }
        return "\(earnedXP) XP earned · \(potentialXP - earnedXP) more available"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            heroHeader
            if !tasks.isEmpty {
                taskSection
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 18) {
            // Label + Add Task button
            HStack(alignment: .center) {
                Text("TODAY'S MISSION")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Button {
                    HapticManager.impact(.medium)
                    onAddTask()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Task")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Ring + headline
            HStack(spacing: 20) {
                progressRing

                VStack(alignment: .leading, spacing: 5) {
                    Text(headlineText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(heroBackground)
    }

    private var heroBackground: some View {
        ZStack {
            AppTheme.heroGradient
            // Subtle highlight
            LinearGradient(
                colors: [.white.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 7)

            // Arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isAllDone ? Color.green : Color.white,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)

            // Center
            if tasks.isEmpty {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                VStack(spacing: 0) {
                    Text("\(completedCount)")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("of \(tasks.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .frame(width: 72, height: 72)
    }

    // MARK: - Task Section

    private var sortedTasks: [DailyTask] {
        tasks.sorted {
            // Incomplete first
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            // Then by time, then by creation
            let aTime = $0.startTime ?? $0.date
            let bTime = $1.startTime ?? $1.date
            return aTime < bTime
        }
    }

    private var visibleTasks: [DailyTask] { Array(sortedTasks.prefix(4)) }

    private var taskSection: some View {
        VStack(spacing: 0) {
            ForEach(visibleTasks) { task in
                taskRow(task)
            }

            if tasks.count > 4 {
                HStack {
                    Text("+ \(tasks.count - 4) more task\(tasks.count - 4 == 1 ? "" : "s")")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.cardPadding)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
            }
        }
        .background(AppTheme.cardBackground)
    }

    private func taskRow(_ task: DailyTask) -> some View {
        HStack(spacing: 12) {
            // Category dot
            Circle()
                .fill(task.isCompleted ? Color(red: 0.20, green: 0.72, blue: 0.45) : task.category.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(AppTheme.TextStyle.bodyBold)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                    .lineLimit(1)

                Text(taskSubtitle(task))
                    .font(AppTheme.TextStyle.micro)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Spacer()

            Text("+\(XPCalculator.xp(for: task)) XP")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(task.isCompleted ? AppTheme.tertiary : AppTheme.onSurfaceVariant)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(task.isCompleted ? AppTheme.tertiary.opacity(0.10) : AppTheme.surfaceContainerLow)
                .clipShape(Capsule())
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 11)
        .background(AppTheme.cardBackground)
    }

    private func taskSubtitle(_ task: DailyTask) -> String {
        if let timeRange = task.formattedTimeRange { return timeRange }
        if task.routineId != nil { return "Routine" }
        if task.tripId != nil { return "Trip task" }
        if task.eventId != nil { return "Event task" }
        return task.categoryDisplayName
    }
}

#Preview("In Progress") {
    ScrollView {
        TodaysMissionView(
            tasks: [
                DailyTask(title: "Morning workout", date: Date(), startTime: Date(), category: .health),
                DailyTask(title: "Review pull requests", date: Date(), category: .work),
                DailyTask(title: "Read 20 pages", date: Date(), isCompleted: true, category: .personal),
                DailyTask(title: "Call mom", date: Date(), isCompleted: true, category: .personal),
                DailyTask(title: "Groceries", date: Date(), category: .errands),
            ],
            onAddTask: {}
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty") {
    TodaysMissionView(tasks: [], onAddTask: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("All Done") {
    TodaysMissionView(
        tasks: [
            DailyTask(title: "Morning workout", date: Date(), isCompleted: true, category: .health),
            DailyTask(title: "Read 20 pages", date: Date(), isCompleted: true, category: .personal),
            DailyTask(title: "Team standup", date: Date(), isCompleted: true, category: .work),
        ],
        onAddTask: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
