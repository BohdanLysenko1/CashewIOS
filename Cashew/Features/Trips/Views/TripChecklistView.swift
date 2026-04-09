import SwiftUI

struct TripChecklistView: View {
    @Binding var trip: Trip
    let initialIntent: TripSectionIntent
    @State private var showAddItem = false
    @State private var editingItem: ChecklistItem?
    @State private var showUrgentOnly = false
    @State private var didApplyInitialIntent = false

    init(trip: Binding<Trip>, initialIntent: TripSectionIntent = .overview) {
        self._trip = trip
        self.initialIntent = initialIntent
    }

    private var pendingItems: [ChecklistItem] {
        trip.checklistItems
            .filter { !$0.isCompleted }
            .filter { !showUrgentOnly || $0.priority == .urgent || $0.priority == .high }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var completedItems: [ChecklistItem] {
        trip.checklistItems.filter { $0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.md) {
                progressCard

                TripSectionCard("View Options", icon: "line.3.horizontal.decrease.circle.fill") {
                    Toggle(isOn: $showUrgentOnly) {
                        Text("Focus on high priority")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)
                    }
                    .tint(AppTheme.secondary)
                }

                if !pendingItems.isEmpty {
                    itemsSection(title: "To Do", items: pendingItems, showPriority: true)
                }

                if !completedItems.isEmpty {
                    itemsSection(title: "Completed", items: completedItems, showPriority: false)
                }

                if showUrgentOnly && pendingItems.isEmpty && !trip.checklistItems.isEmpty {
                    focusedFilterEmptyView
                }

                if trip.checklistItems.isEmpty {
                    emptyView
                }

                if !remainingSuggestions.isEmpty {
                    suggestionsSection
                }
            }
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.vertical, AppTheme.Space.md)
        }
        .background(AppTheme.background)
        .navigationTitle("Checklist")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            ChecklistItemFormView(trip: $trip, item: nil)
        }
        .sheet(item: $editingItem) { item in
            ChecklistItemFormView(trip: $trip, item: item)
        }
        .onAppear {
            applyInitialIntentIfNeeded()
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        let completed = completedItems.count
        let total = trip.checklistItems.count
        let urgentCount = pendingItems.filter { $0.priority == .urgent }.count

        return TripHeroCard(
            icon: "checklist",
            title: "Checklist",
            subtitle: total == 0 ? "Build your departure task list" : "\(completed) of \(total) tasks done"
        ) {
            HStack(spacing: AppTheme.Space.sm) {
                TripMetricPill(label: "Done", value: "\(completed)")
                TripMetricPill(label: "Left", value: "\(max(0, total - completed))")
                TripMetricPill(label: "Urgent", value: "\(urgentCount)")
            }

            AppProgressBar(progress: trip.checklistProgress, color: progressColor)
                .frame(height: AppTheme.progressBarHeight)

            if trip.checklistProgress == 1.0 && !trip.checklistItems.isEmpty {
                Label("All tasks completed!", systemImage: "checkmark.circle.fill")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }

    private var progressColor: Color {
        if trip.checklistProgress == 1.0 { return .green }
        if trip.checklistProgress > 0.5 { return .blue }
        return .orange
    }

    // MARK: - Items Section

    private func itemsSection(title: String, items: [ChecklistItem], showPriority: Bool) -> some View {
        TripSectionCard(title, icon: title == "Completed" ? "checkmark.circle.fill" : "list.bullet.rectangle") {
            HStack {
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(AppTheme.TextStyle.secondary)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                Spacer()
                Text(title)
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(spacing: AppTheme.Space.xs) {
                ForEach(items) { item in
                    ChecklistItemRow(item: item, showPriority: showPriority) {
                        toggleItem(item)
                    } onEdit: {
                        editingItem = item
                    } onDelete: {
                        deleteItem(item)
                    }
                }
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.onSurfaceVariant)

            VStack(spacing: 6) {
                Text("No Tasks Yet")
                    .font(.headline)

                Text("Create a pre-trip checklist")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Button {
                showAddItem = true
            } label: {
                Label("Add Task", systemImage: "plus")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(AppTheme.Space.lg)
        .tripModuleCard()
    }

    private var focusedFilterEmptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("No high-priority tasks left")
                .font(.headline)
                .foregroundStyle(AppTheme.onSurface)
            Text("Switch off the filter to see medium and low priority items.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(AppTheme.Space.lg)
        .tripModuleCard()
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        TripSectionCard("Common Tasks", icon: "lightbulb.fill") {
            VStack(spacing: AppTheme.Space.sm) {
                ForEach(remainingSuggestions, id: \.self) { task in
                    Button {
                        addTask(task)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)

                            Text(task)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.onSurface)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .tripSoftSurface()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var commonTasks: [String] {
        [
            "Book accommodation",
            "Book flights",
            "Check passport validity",
            "Get travel insurance",
            "Exchange currency",
            "Notify bank of travel",
            "Download offline maps",
            "Arrange pet care",
            "Set up out-of-office",
            "Confirm reservations"
        ]
    }

    private var remainingSuggestions: [String] {
        let existingTitles = Set(trip.checklistItems.map { $0.title.lowercased() })
        return commonTasks.filter { !existingTitles.contains($0.lowercased()) }
    }

    // MARK: - Actions

    private func toggleItem(_ item: ChecklistItem) {
        if let index = trip.checklistItems.firstIndex(where: { $0.id == item.id }) {
            withAnimation(.spring(response: 0.3)) {
                trip.checklistItems[index].isCompleted.toggle()
            }
        }
    }

    private func deleteItem(_ item: ChecklistItem) {
        trip.checklistItems.removeAll { $0.id == item.id }
    }

    private func addTask(_ title: String) {
        withAnimation {
            let item = ChecklistItem(title: title)
            trip.checklistItems.append(item)
        }
    }

    private func applyInitialIntentIfNeeded() {
        guard !didApplyInitialIntent else { return }
        didApplyInitialIntent = true

        switch initialIntent {
        case .addChecklistItem:
            showAddItem = true
        case .reviewChecklist:
            showUrgentOnly = true
        default:
            break
        }
    }
}

// MARK: - Checklist Item Row

private struct ChecklistItemRow: View {
    let item: ChecklistItem
    let showPriority: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var checkScale: CGFloat = 1.0
    @State private var showConfetti = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Button {
                triggerToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isCompleted ? .green : priorityColor)
                    .scaleEffect(checkScale)
                    .symbolEffect(.bounce, value: item.isCompleted)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .center) {
                if showConfetti {
                    ConfettiView()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)

                    if showPriority && item.priority != .medium {
                        Image(systemName: item.priority.icon)
                            .font(.caption)
                            .foregroundStyle(priorityColor)
                    }
                }

                if let dueDate = item.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(Self.dateFormatter.string(from: dueDate))
                            .font(.caption)
                    }
                    .foregroundStyle(isOverdue ? .red : .secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .tripSoftSurface()
        .contentShape(Rectangle())
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var priorityColor: Color {
        switch item.priority {
        case .low: return .green
        case .medium: return .secondary
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private var isOverdue: Bool {
        guard let dueDate = item.dueDate, !item.isCompleted else { return false }
        return dueDate < Date()
    }

    private func triggerToggle() {
        let completing = !item.isCompleted
        if completing {
            HapticManager.notification(.success)
        } else {
            HapticManager.impact(.light)
        }

        withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.4)) {
            checkScale = 1.35
        }
        withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.6).delay(0.15)) {
            checkScale = 1.0
        }

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

// MARK: - Checklist Item Form

struct ChecklistItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip

    let item: ChecklistItem?

    @State private var title: String = ""
    @State private var priority: ChecklistPriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate: Date = Date()
    @State private var notes: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case title, notes }

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: item == nil ? "Add Task" : "Edit Task",
                subtitle: nil,
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    CreationSectionCard(title: "Task", icon: "checklist") {
                        TextField("Task", text: $title)
                            .focused($focusedField, equals: .title)
                            .designField(isFocused: focusedField == .title)
                    }

                    CreationSectionCard(title: "Details", icon: "slider.horizontal.3") {
                        VStack(spacing: AppTheme.Space.sm) {
                            HStack {
                                Text("Priority")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurface)
                                Spacer()
                                Picker("Priority", selection: $priority) {
                                    ForEach(ChecklistPriority.allCases, id: \.self) { p in
                                        Label(p.displayName, systemImage: p.icon).tag(p)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.secondary)
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Toggle("Due Date", isOn: $hasDueDate)
                                .font(AppTheme.TextStyle.body)
                                .tint(AppTheme.secondary)
                                .padding(.horizontal, AppTheme.Space.md)
                                .padding(.vertical, AppTheme.Space.sm)
                                .background(AppTheme.surfaceContainer)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            if hasDueDate {
                                HStack {
                                    Text("Due Date")
                                        .font(AppTheme.TextStyle.body)
                                        .foregroundStyle(AppTheme.onSurface)
                                    Spacer()
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(AppTheme.secondary)
                                }
                                .padding(.horizontal, AppTheme.Space.md)
                                .padding(.vertical, AppTheme.Space.sm)
                                .background(AppTheme.surfaceContainer)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }

                    CreationSectionCard(title: "Notes", icon: "note.text") {
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .focused($focusedField, equals: .notes)
                            .designField(isFocused: focusedField == .notes)
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.bottom, AppTheme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Cancel",
                confirmTitle: item == nil ? "Add Task" : "Save Task",
                gradient: AppTheme.tripGradient,
                canConfirm: !title.isEmpty,
                isLoading: false,
                onCancel: { dismiss() },
                onConfirm: { saveItem(); dismiss() }
            )
        }
        .background(CreationScreenBackground(gradient: AppTheme.tripGradient))
        .presentationDetents([.medium])
        .onAppear {
            if let item {
                title = item.title
                priority = item.priority
                hasDueDate = item.dueDate != nil
                dueDate = item.dueDate ?? Date()
                notes = item.notes
            }
        }
    }

    private func saveItem() {
        if let item {
            if let index = trip.checklistItems.firstIndex(where: { $0.id == item.id }) {
                trip.checklistItems[index].title = title
                trip.checklistItems[index].priority = priority
                trip.checklistItems[index].dueDate = hasDueDate ? dueDate : nil
                trip.checklistItems[index].notes = notes
            }
        } else {
            let newItem = ChecklistItem(
                title: title,
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority,
                notes: notes
            )
            trip.checklistItems.append(newItem)
        }
    }
}

#Preview {
    NavigationStack {
        TripChecklistView(trip: .constant(Trip(
            name: "Paris Trip",
            destination: "Paris, France",
            startDate: Date().addingTimeInterval(86400 * 30),
            endDate: Date().addingTimeInterval(86400 * 37),
            checklistItems: [
                ChecklistItem(title: "Book flights", isCompleted: true, priority: .high),
                ChecklistItem(title: "Reserve hotel", dueDate: Date().addingTimeInterval(86400 * 7), priority: .high),
                ChecklistItem(title: "Get travel insurance", priority: .medium),
                ChecklistItem(title: "Check passport", isCompleted: true, priority: .urgent)
            ]
        )))
    }
}
