import SwiftUI

struct DayPlannerSnapshotView: View {

    let tasks: [DailyTask]
    let onAddTask: () -> Void

    private var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(tasks.count)
    }

    private var scheduledTasks: [DailyTask] {
        tasks
            .filter { $0.startTime != nil }
            .sorted { ($0.startTime ?? $0.date) < ($1.startTime ?? $1.date) }
    }

    private var nextTask: DailyTask? {
        let now = Date()
        return scheduledTasks.first { task in
            !task.isCompleted && (task.startTime ?? task.date) >= now
        } ?? tasks.first { !$0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.dayPlannerGradient)
                    Text("Today's Plan")
                        .font(AppTheme.TextStyle.sectionTitle)
                        .foregroundStyle(AppTheme.onSurface)
                }

                Spacer()

                Button(action: onAddTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.dayPlannerGradient)
                }
            }

            if tasks.isEmpty {
                emptyState
            } else {
                // Progress + Next Up
                HStack(spacing: 16) {
                    progressRing
                    nextUpCard
                }

                // Mini timeline
                if !scheduledTasks.isEmpty {
                    miniTimeline
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(AppTheme.onSurfaceVariant)

            VStack(alignment: .leading, spacing: 2) {
                Text("No tasks planned")
                    .font(AppTheme.TextStyle.bodyBold)
                    .foregroundStyle(AppTheme.onSurface)
                Text("Tap + to plan your day")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(AppTheme.surfaceContainerHigh, lineWidth: 7)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress)

                VStack(spacing: 0) {
                    Text("\(completedCount)")
                        .font(AppTheme.TextStyle.sectionTitle)
                        .foregroundStyle(AppTheme.onSurface)
                    Text("of \(tasks.count)")
                        .font(AppTheme.TextStyle.micro)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }

            Text(progressLabel)
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(progressColor)
        }
    }

    private var progressGradient: LinearGradient {
        if progress >= 1.0 {
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if progress > 0.5 {
            return AppTheme.dayPlannerGradient
        } else {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .green }
        if progress > 0.5 { return .green }
        return .orange
    }

    private var progressLabel: String {
        if progress >= 1.0 { return "All done!" }
        let remaining = tasks.count - completedCount
        return "\(remaining) left"
    }

    // MARK: - Next Up Card

    private var nextUpCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let next = nextTask {
                Text("NEXT UP")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .tracking(0.5)

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(next.category.color.gradient)
                        .frame(width: 4, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(next.title)
                            .font(AppTheme.TextStyle.bodyBold)
                            .foregroundStyle(AppTheme.onSurface)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            if let timeRange = next.formattedTimeRange {
                                Image(systemName: "clock")
                                    .font(AppTheme.TextStyle.micro)
                                Text(timeRange)
                                    .font(AppTheme.TextStyle.caption)
                            } else {
                                Image(systemName: next.category.icon)
                                    .font(AppTheme.TextStyle.micro)
                                Text(next.categoryDisplayName)
                                    .font(AppTheme.TextStyle.caption)
                            }
                        }
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }
            } else {
                Text("ALL TASKS DONE")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(Color(red: 0.20, green: 0.72, blue: 0.45))
                    .tracking(0.5)

                Text("Great work today!")
                    .font(AppTheme.TextStyle.body)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
    }

    // MARK: - Mini Timeline

    private var miniTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(scheduledTasks.prefix(4).enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 10) {
                    // Time
                    Text(timeString(task.startTime))
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .frame(width: 52, alignment: .trailing)
                        .monospacedDigit()

                    // Dot + Line
                    VStack(spacing: 0) {
                        if index > 0 {
                            Rectangle()
                                .fill(AppTheme.surfaceContainerHigh)
                                .frame(width: 1, height: 8)
                        }
                        Circle()
                            .fill(task.isCompleted ? Color(red: 0.20, green: 0.72, blue: 0.45) : task.category.color)
                            .frame(width: 8, height: 8)
                        if index < min(scheduledTasks.count, 4) - 1 {
                            Rectangle()
                                .fill(AppTheme.surfaceContainerHigh)
                                .frame(width: 1, height: 8)
                        }
                    }

                    // Title
                    Text(task.title)
                        .font(AppTheme.TextStyle.caption)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                        .lineLimit(1)

                    Spacer()

                    if task.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 2)
            }

            if scheduledTasks.count > 4 {
                Text("+\(scheduledTasks.count - 4) more")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private func timeString(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.timeFormatter.string(from: date)
    }
}
