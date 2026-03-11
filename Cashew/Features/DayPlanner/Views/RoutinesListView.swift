import SwiftUI

struct RoutinesListView: View {

    @Environment(\.dismiss) private var dismiss

    let service: DayPlannerServiceProtocol

    @State private var showAddRoutine = false
    @State private var editingRoutine: DailyRoutine?

    var body: some View {
        NavigationStack {
            Group {
                if service.routines.isEmpty {
                    emptyView
                } else {
                    routinesList
                }
            }
            .navigationTitle("Routines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddRoutine = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddRoutine) {
                RoutineFormView(service: service, routine: nil)
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineFormView(service: service, routine: routine)
            }
        }
    }

    // MARK: - Routines List

    private var routinesList: some View {
        List {
            ForEach(service.routines) { routine in
                RoutineRow(
                    routine: routine,
                    onToggle: { toggleRoutine(routine) },
                    onEdit: { editingRoutine = routine }
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteRoutine(routine)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "repeat")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No Routines Yet")
                    .font(.headline)

                Text("Create routines for tasks that repeat daily")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddRoutine = true
            } label: {
                Label("Create Routine", systemImage: "plus")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Actions

    private func toggleRoutine(_ routine: DailyRoutine) {
        Task {
            do { try await service.toggleRoutineEnabled(routine) }
            catch { print("[RoutinesListView] Failed to toggle routine: \(error)") }
        }
    }

    private func deleteRoutine(_ routine: DailyRoutine) {
        Task {
            do { try await service.deleteRoutine(by: routine.id) }
            catch { print("[RoutinesListView] Failed to delete routine: \(error)") }
        }
    }
}

// MARK: - Routine Row

private struct RoutineRow: View {
    let routine: DailyRoutine
    let onToggle: () -> Void
    let onEdit: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: routine.category.icon)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(routine.isEnabled ? routine.category.color.gradient : Color.gray.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(routine.isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    // Repeat pattern
                    Text(routine.repeatDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Time if set
                    if let startTime = routine.startTime {
                        Text("at \(Self.timeFormatter.string(from: startTime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { routine.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

#Preview {
    RoutinesListView(
        service: DayPlannerService(
            taskRepository: LocalDailyTaskRepository(),
            routineRepository: LocalDailyRoutineRepository()
        )
    )
}
