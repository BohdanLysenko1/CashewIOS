import SwiftUI

struct ScheduleTimelineView: View {
    let tasks: [DailyTask]
    var linkResolver: ((DailyTask) -> (icon: String, label: String)?)?
    let onToggle: (DailyTask) -> Void
    let onDetail: (DailyTask) -> Void
    let onEdit: (DailyTask) -> Void
    let onDelete: (DailyTask) -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(tasks) { task in
                HStack(alignment: .top, spacing: 12) {
                    // Time column
                    VStack(alignment: .trailing, spacing: 2) {
                        if let startTime = task.startTime {
                            Text(Self.timeFormatter.string(from: startTime))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                        }

                        if let endTime = task.endTime {
                            Text(Self.timeFormatter.string(from: endTime))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }
                    .frame(width: 55, alignment: .trailing)

                    // Timeline indicator
                    VStack(spacing: 0) {
                        Circle()
                            .fill(task.isCompleted ? .green : task.category.color)
                            .frame(width: 12, height: 12)

                        if task.id != tasks.last?.id {
                            Rectangle()
                                .fill(AppTheme.surfaceContainerHigh)
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }

                    // Task card
                    taskCard(task)
                }
                .frame(minHeight: 70)
            }
        }
    }

    private func taskCard(_ task: DailyTask) -> some View {
        HStack(spacing: 10) {
            Button {
                onToggle(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(task.isCompleted ? .green : task.category.color)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)

                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: task.category.icon)
                            .font(.caption2)
                        Text(task.categoryDisplayName)
                            .font(.caption)
                    }
                    .foregroundStyle(task.category.color.opacity(0.8))

                    if task.routineId != nil {
                        RoutineBadge()
                    }
                }

                if let link = linkResolver?(task) {
                    HStack(spacing: 3) {
                        Image(systemName: link.icon)
                            .font(.caption2)
                        Text(link.label)
                            .font(.caption)
                    }
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            onDetail(task)
        }
        .contextMenu {
            Button { onEdit(task) } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) { onDelete(task) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ScrollView {
        ScheduleTimelineView(
            tasks: [
                DailyTask(title: "Morning workout", date: Date(), startTime: Date(), endTime: Date().addingTimeInterval(3600), category: .health),
                DailyTask(title: "Team standup", date: Date(), startTime: Date().addingTimeInterval(3600 * 2), category: .work),
                DailyTask(title: "Lunch with client", date: Date(), startTime: Date().addingTimeInterval(3600 * 5), endTime: Date().addingTimeInterval(3600 * 6), isCompleted: true, category: .social)
            ],
            onToggle: { _ in },
            onDetail: { _ in },
            onEdit: { _ in },
            onDelete: { _ in }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
