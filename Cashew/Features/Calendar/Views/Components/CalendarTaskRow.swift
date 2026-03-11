import SwiftUI

struct CalendarTaskRow: View {
    let task: DailyTask
    let service: DayPlannerServiceProtocol

    @State private var isToggling = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                toggleTask()
            } label: {
                Group {
                    if isToggling {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    }
                }
                .font(.system(size: 22))
                .foregroundStyle(task.isCompleted ? .green : task.category.color)
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(isToggling)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Category
                    Label(task.categoryDisplayName, systemImage: task.category.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Time if scheduled
                    if let timeRange = task.formattedTimeRange {
                        Text("· \(timeRange)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if task.routineId != nil {
                        RoutineBadge()
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func toggleTask() {
        guard !isToggling else { return }
        isToggling = true

        if task.isCompleted {
            HapticManager.impact(.light)
        } else {
            HapticManager.notification(.success)
        }

        Task {
            do {
                try await service.toggleTaskCompletion(task)
            } catch {
                // Toggle failed — service's @Observable state remains unchanged so UI reverts automatically
                print("[CalendarTaskRow] Toggle failed: \(error)")
            }
            isToggling = false
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        CalendarTaskRow(
            task: DailyTask(
                title: "Morning workout",
                date: Date(),
                startTime: Date(),
                category: .health
            ),
            service: DayPlannerService(
                taskRepository: LocalDailyTaskRepository(),
                routineRepository: LocalDailyRoutineRepository()
            )
        )

        CalendarTaskRow(
            task: DailyTask(
                title: "Completed task",
                date: Date(),
                isCompleted: true,
                category: .work
            ),
            service: DayPlannerService(
                taskRepository: LocalDailyTaskRepository(),
                routineRepository: LocalDailyRoutineRepository()
            )
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
