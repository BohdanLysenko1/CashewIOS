import SwiftUI

struct RoutinesListView: View {

    @Environment(\.dismiss) private var dismiss

    let service: DayPlannerServiceProtocol

    @State private var showAddRoutine = false
    @State private var editingRoutine: DailyRoutine?
    @State private var routinePendingDeletion: DailyRoutine?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                Group {
                    if service.routines.isEmpty {
                        emptyView
                    } else {
                        routinesList
                    }
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
            .confirmationDialog(
                "Delete Routine?",
                isPresented: Binding(
                    get: { routinePendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented { routinePendingDeletion = nil }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let routinePendingDeletion else { return }
                    deleteRoutine(routinePendingDeletion)
                    self.routinePendingDeletion = nil
                }
            } message: {
                if let routinePendingDeletion {
                    Text("\"\(routinePendingDeletion.title)\" will be removed.")
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
        ScrollView {
            LazyVStack(spacing: AppTheme.Space.md) {
                routinesSummaryCard

                ForEach(service.routines) { routine in
                    RoutineCard(
                        routine: routine,
                        onToggle: { toggleRoutine(routine) },
                        onEdit: { editingRoutine = routine },
                        onDelete: { routinePendingDeletion = routine }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.vertical, AppTheme.Space.md)
            .padding(.bottom, AppTheme.Space.lg)
        }
    }

    private var routinesSummaryCard: some View {
        HStack(spacing: AppTheme.Space.sm) {
            summaryPill(
                icon: "repeat.circle.fill",
                title: "Total",
                value: "\(service.routines.count)",
                tint: AppTheme.primary
            )

            summaryPill(
                icon: "checkmark.circle.fill",
                title: "Enabled",
                value: "\(service.routines.filter(\.isEnabled).count)",
                tint: .green
            )
        }
        .padding(AppTheme.Space.sm)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
    }

    private func summaryPill(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(AppTheme.TextStyle.caption)
            }
            .foregroundStyle(tint)

            Text(value)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(AppTheme.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "repeat")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.dayPlannerGradient)

            VStack(spacing: 6) {
                Text("No Routines Yet")
                    .font(.headline)

                Text("Create routines for tasks that repeat daily")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
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
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Space.lg)
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

private struct RoutineCard: View {
    let routine: DailyRoutine
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private var timeDescription: String? {
        guard let startTime = routine.startTime else { return nil }
        if let endTime = routine.endTime {
            return "\(Self.timeFormatter.string(from: startTime)) - \(Self.timeFormatter.string(from: endTime))"
        }
        return Self.timeFormatter.string(from: startTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
            HStack(alignment: .top, spacing: AppTheme.Space.md) {
                Image(systemName: routine.category.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(routine.isEnabled ? routine.category.color.gradient : AppTheme.onSurfaceVariant.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(routine.title)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(routine.isEnabled ? AppTheme.onSurface : AppTheme.onSurfaceVariant)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        metadataChip(icon: "repeat", label: routine.repeatDescription, tint: AppTheme.primary)

                        if let timeDescription {
                            metadataChip(icon: "clock.fill", label: timeDescription, tint: AppTheme.onSurfaceVariant)
                        }

                        if !routine.isEnabled {
                            metadataChip(icon: "pause.fill", label: "Paused", tint: AppTheme.onSurfaceVariant)
                        }
                    }
                }

                Spacer(minLength: AppTheme.Space.sm)

                VStack(spacing: AppTheme.Space.sm) {
                    Toggle("", isOn: Binding(
                        get: { routine.isEnabled },
                        set: { _ in onToggle() }
                    ))
                    .labelsHidden()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(8)
                            .background(Color.red.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if !routine.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(routine.notes)
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .lineLimit(2)
            }
        }
        .padding(AppTheme.Space.md)
        .background(routine.isEnabled ? AppTheme.cardBackground : AppTheme.surfaceContainerLow.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(routine.isEnabled ? AppTheme.outlineVariant : AppTheme.surfaceContainerHigh, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            onEdit()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
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
}

#Preview {
    RoutinesListView(
        service: DayPlannerService(
            taskRepository: LocalDailyTaskRepository(),
            routineRepository: LocalDailyRoutineRepository()
        )
    )
}
