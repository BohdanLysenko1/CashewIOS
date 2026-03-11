import SwiftUI

struct TodaysMissionView: View {

    let tasks: [DailyTask]
    let onAddTask: () -> Void

    private var completedCount: Int { tasks.filter(\.isCompleted).count }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(tasks.count)
    }

    private var potentialXP: Int {
        tasks.reduce(0) { $0 + XPCalculator.xp(for: $1) } + XPCalculator.dayCompletionBonus
    }

    private var earnedXP: Int {
        let base = tasks.filter(\.isCompleted).reduce(0) { $0 + XPCalculator.xp(for: $1) }
        let bonus = (!tasks.isEmpty && completedCount == tasks.count) ? XPCalculator.dayCompletionBonus : 0
        return base + bonus
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if tasks.isEmpty {
                emptyState
            } else {
                taskList
                progressBar
                rewardRow
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.dayPlannerGradient)
                Text("Today's Mission")
                    .font(.headline)
                    .fontWeight(.bold)
            }

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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.dayPlannerGradient)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("No mission yet")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Tap Add Task to start your day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Task List

    private var sortedTasks: [DailyTask] {
        tasks.sorted {
            let aTime = $0.startTime ?? $0.date
            let bTime = $1.startTime ?? $1.date
            return aTime < bTime
        }
    }

    private var visibleTasks: [DailyTask] { Array(sortedTasks.prefix(5)) }

    private var taskList: some View {
        VStack(spacing: 0) {
            ForEach(visibleTasks) { task in
                taskRow(task)
                if task.id != visibleTasks.last?.id {
                    Divider().padding(.leading, 28)
                }
            }

            if tasks.count > 5 {
                HStack {
                    Spacer()
                    Text("+\(tasks.count - 5) more tasks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func taskRow(_ task: DailyTask) -> some View {
        HStack(spacing: 10) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(task.isCompleted ? .green : Color(.systemGray3))

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                Text(taskSubtitle(task))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("+\(XPCalculator.xp(for: task)) XP")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(task.isCompleted ? .green : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((task.isCompleted ? Color.green : Color(.systemGray5)).opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func taskSubtitle(_ task: DailyTask) -> String {
        if let timeRange = task.formattedTimeRange { return timeRange }
        if task.routineId != nil { return "Routine" }
        if task.tripId != nil { return "Trip task" }
        if task.eventId != nil { return "Event task" }
        return task.categoryDisplayName
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedCount)/\(tasks.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                let segments = max(tasks.count, 1)
                let segmentWidth = (geo.size.width - CGFloat(segments - 1) * 4) / CGFloat(segments)

                HStack(spacing: 4) {
                    ForEach(0..<segments, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index < completedCount
                                  ? LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray5)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: segmentWidth, height: 8)
                            .animation(.spring(response: 0.4), value: completedCount)
                    }
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Reward Row

    private var rewardRow: some View {
        HStack {
            if earnedXP > 0 {
                Label("\(earnedXP) XP earned", systemImage: "star.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
            Spacer()
            Label("Reward: +\(potentialXP) XP", systemImage: "trophy.fill")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(progress >= 1.0 ? .yellow : .secondary)
        }
    }
}
