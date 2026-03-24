import SwiftUI

struct DailyTaskRow: View {
    let task: DailyTask
    var linkIcon: String? = nil
    var linkLabel: String? = nil
    let onToggle: () -> Void
    var onSubtaskToggle: ((UUID) -> Void)? = nil
    let onDetail: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var checkScale: CGFloat = 1.0
    @State private var showConfetti = false
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Checkbox
                Button {
                    triggerToggle()
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(task.isCompleted ? .green : task.category.color)
                        .scaleEffect(checkScale)
                        .symbolEffect(.bounce, value: task.isCompleted)
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: task.category.icon)
                                .font(.caption2)
                            Text(task.categoryDisplayName)
                                .font(.caption)
                        }
                        .foregroundStyle(task.category.color)

                        if task.routineId != nil {
                            RoutineBadge()
                        }

                        if let timeRange = task.formattedTimeRange {
                            Text(timeRange)
                                .font(.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }

                        if task.hasSubtasks {
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.caption2)
                                Text(task.subtaskProgress)
                                    .font(.caption)
                            }
                            .foregroundStyle(task.allSubtasksCompleted ? .green : AppTheme.onSurfaceVariant)
                        }

                        if let icon = linkIcon, let label = linkLabel {
                            HStack(spacing: 3) {
                                Image(systemName: icon)
                                    .font(.caption2)
                                Text(label)
                                    .font(.caption)
                            }
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }
                }

                Spacer()

                // Expand/collapse chevron for subtasks, plain chevron otherwise
                if task.hasSubtasks {
                    Button {
                        withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                        HapticManager.selection()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture { onDetail() }
            .overlay(alignment: .leading) {
                if showConfetti {
                    ConfettiView()
                        .offset(x: 28)
                }
            }

            // Subtask list (expanded)
            if isExpanded && task.hasSubtasks {
                VStack(spacing: 0) {
                    ForEach(task.subtasks) { subtask in
                        HStack(spacing: 12) {
                            Spacer().frame(width: 20)

                            Button {
                                onSubtaskToggle?(subtask.id)
                                HapticManager.impact(subtask.isCompleted ? .light : .medium)
                            } label: {
                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(subtask.isCompleted ? .green : AppTheme.onSurfaceVariant)
                            }
                            .buttonStyle(.plain)

                            Text(subtask.title)
                                .font(.subheadline)
                                .strikethrough(subtask.isCompleted)
                                .foregroundStyle(subtask.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                                .animation(.easeInOut(duration: 0.2), value: subtask.isCompleted)

                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Toggle

    private func triggerToggle() {
        let completing = !task.isCompleted

        // Haptic
        if completing {
            HapticManager.notification(.success)
        } else {
            HapticManager.impact(.light)
        }

        // Check bounce
        withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.4)) {
            checkScale = 1.35
        }
        withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.6).delay(0.15)) {
            checkScale = 1.0
        }

        // Confetti on completion only
        if completing {
            showConfetti = true
            Task {
                try? await Task.sleep(for: .seconds(AppTheme.confettiLifetime))
                showConfetti = false
            }
        }

        onToggle()
    }
}

#Preview {
    VStack(spacing: 0) {
        DailyTaskRow(
            task: DailyTask(title: "Morning workout", date: Date(), startTime: Date(),
                            endTime: Date().addingTimeInterval(3600), category: .health),
            onToggle: {}, onDetail: {}, onEdit: {}, onDelete: {}
        )
        Divider().padding(.leading, 50)
        DailyTaskRow(
            task: DailyTask(title: "Buy groceries", date: Date(), category: .errands),
            onToggle: {}, onDetail: {}, onEdit: {}, onDelete: {}
        )
        Divider().padding(.leading, 50)
        DailyTaskRow(
            task: DailyTask(title: "Completed task", date: Date(), isCompleted: true, category: .work),
            onToggle: {}, onDetail: {}, onEdit: {}, onDelete: {}
        )
    }
    .background(AppTheme.cardBackground)
}
