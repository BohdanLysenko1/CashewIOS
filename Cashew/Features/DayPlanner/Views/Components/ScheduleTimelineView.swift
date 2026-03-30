import SwiftUI

struct ScheduleTimelineView: View {
    let tasks: [DailyTask]
    var linkResolver: ((DailyTask) -> (icon: String, label: String)?)?
    let onToggle: (DailyTask) -> Void
    let onDetail: (DailyTask) -> Void
    let onEdit: (DailyTask) -> Void
    let onDelete: (DailyTask) -> Void
    @State private var checkScaleByTaskId: [UUID: CGFloat] = [:]
    @State private var confettiTaskIds: Set<UUID> = []

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                timelineRow(task, isLast: index == tasks.count - 1)
            }
        }
        .padding(AppTheme.Space.sm)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
        .shadow(color: AppTheme.cardShadow, radius: 18, x: 0, y: 6)
    }

    private func timelineRow(_ task: DailyTask, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            timeColumn(for: task)
            timelineIndicator(for: task, isLast: isLast)
            taskCard(task)
        }
        .frame(minHeight: 82)
    }

    private func timeColumn(for task: DailyTask) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let startTime = task.startTime {
                Text(Self.timeFormatter.string(from: startTime))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(Capsule())
            }

            if let endTime = task.endTime {
                Text(Self.timeFormatter.string(from: endTime))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
        .frame(width: 70, alignment: .trailing)
        .padding(.top, 3)
    }

    private func timelineIndicator(for task: DailyTask, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(task.isCompleted ? .green : task.category.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                )

            if !isLast {
                Rectangle()
                    .fill(AppTheme.surfaceContainerHigh)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 3)
            }
        }
        .frame(width: 12)
    }

    private func taskCard(_ task: DailyTask) -> some View {
        HStack(spacing: AppTheme.Space.sm) {
            Button {
                triggerToggle(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(task.isCompleted ? .green : task.category.color)
                    .scaleEffect(checkScaleByTaskId[task.id] ?? 1.0)
                    .symbolEffect(.bounce, value: task.isCompleted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(AppTheme.TextStyle.bodyBold)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    metadataChip(
                        icon: task.category.icon,
                        label: task.categoryDisplayName,
                        tint: task.category.color
                    )

                    if task.routineId != nil {
                        RoutineBadge()
                    }
                }

                if let link = linkResolver?(task) {
                    metadataChip(
                        icon: link.icon,
                        label: link.label,
                        tint: AppTheme.onSurfaceVariant
                    )
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.75))
                .padding(8)
                .background(AppTheme.surfaceContainerLow)
                .clipShape(Circle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(task.isCompleted ? AppTheme.surfaceContainerLow.opacity(0.85) : AppTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(task.isCompleted ? AppTheme.surfaceContainerHigh : AppTheme.outlineVariant, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onDetail(task)
        }
        .overlay(alignment: .leading) {
            if confettiTaskIds.contains(task.id) {
                ConfettiView()
                    .offset(x: 24)
            }
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

    private func metadataChip(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(AppTheme.TextStyle.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
    }

    private func triggerToggle(_ task: DailyTask) {
        let isCompleting = !task.isCompleted

        if isCompleting {
            HapticManager.notification(.success)
            confettiTaskIds.insert(task.id)
            Task {
                try? await Task.sleep(for: .seconds(AppTheme.confettiLifetime))
                confettiTaskIds.remove(task.id)
            }
        } else {
            HapticManager.impact(.light)
        }

        withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.4)) {
            checkScaleByTaskId[task.id] = AppTheme.checkBounceScale
        }
        withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.6).delay(0.15)) {
            checkScaleByTaskId[task.id] = 1.0
        }

        onToggle(task)
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
