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
            rowCard

            if isExpanded && task.hasSubtasks {
                VStack(spacing: 0) {
                    ForEach(task.subtasks) { subtask in
                        HStack(spacing: 12) {
                            Spacer().frame(width: 16)

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
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .background(AppTheme.surfaceContainerLow.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
                )
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var rowCard: some View {
        HStack(spacing: 12) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(AppTheme.TextStyle.bodyBold)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                taskMetadata
            }

            Spacer(minLength: 0)

            trailingDisclosure
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(task.isCompleted ? AppTheme.surfaceContainerLow.opacity(0.85) : AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(task.isCompleted ? AppTheme.surfaceContainerHigh : AppTheme.outlineVariant, lineWidth: 1)
        )
        .shadow(color: task.isCompleted ? .clear : AppTheme.cardShadow.opacity(0.8), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { onDetail() }
        .overlay(alignment: .leading) {
            if showConfetti {
                ConfettiView()
                    .offset(x: 28)
            }
        }
    }

    private var taskMetadata: some View {
        ViewThatFits(in: .horizontal) {
            metadataContent(showExtras: true)
            metadataContent(showExtras: false)
        }
    }

    @ViewBuilder
    private func metadataContent(showExtras: Bool) -> some View {
        HStack(spacing: 6) {
            metadataChip(icon: task.category.icon, label: task.categoryDisplayName, tint: task.category.color)

            if task.routineId != nil {
                RoutineBadge()
            }

            if let timeRange = task.formattedTimeRange {
                metadataChip(icon: "clock.fill", label: timeRange, tint: AppTheme.onSurfaceVariant)
            }

            if showExtras, task.hasSubtasks {
                metadataChip(
                    icon: "checklist",
                    label: task.subtaskProgress,
                    tint: task.allSubtasksCompleted ? .green : AppTheme.onSurfaceVariant
                )
            }

            if showExtras, let icon = linkIcon, let label = linkLabel {
                metadataChip(icon: icon, label: label, tint: AppTheme.onSurfaceVariant)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var trailingDisclosure: some View {
        if task.hasSubtasks {
            Button {
                withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                HapticManager.selection()
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(8)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.8))
                .padding(8)
                .background(AppTheme.surfaceContainerLow)
                .clipShape(Circle())
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
    VStack(spacing: 10) {
        DailyTaskRow(
            task: DailyTask(title: "Morning workout", date: Date(), startTime: Date(),
                            endTime: Date().addingTimeInterval(3600), category: .health),
            onToggle: {}, onDetail: {}, onEdit: {}, onDelete: {}
        )
        DailyTaskRow(
            task: DailyTask(title: "Buy groceries", date: Date(), category: .errands),
            onToggle: {}, onDetail: {}, onEdit: {}, onDelete: {}
        )
        DailyTaskRow(
            task: DailyTask(title: "Completed task", date: Date(), isCompleted: true, category: .work),
            onToggle: {}, onDetail: {}, onEdit: {}, onDelete: {}
        )
    }
    .padding()
    .background(AppTheme.cardBackground)
}
