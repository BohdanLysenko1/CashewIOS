import SwiftUI

struct TripChecklistView: View {
    @Binding var trip: Trip
    @State private var showAddItem = false
    @State private var editingItem: ChecklistItem?

    private var pendingItems: [ChecklistItem] {
        trip.checklistItems.filter { !$0.isCompleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var completedItems: [ChecklistItem] {
        trip.checklistItems.filter { $0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress Card
                progressCard

                // Pending Items
                if !pendingItems.isEmpty {
                    itemsSection(title: "To Do", items: pendingItems, showPriority: true)
                }

                // Completed Items
                if !completedItems.isEmpty {
                    itemsSection(title: "Completed", items: completedItems, showPriority: false)
                }

                // Empty State
                if trip.checklistItems.isEmpty {
                    emptyView
                }

                // Suggestions
                if !remainingSuggestions.isEmpty {
                    suggestionsSection
                }
            }
            .padding()
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
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Checklist Progress")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    let completed = completedItems.count
                    let total = trip.checklistItems.count

                    Text("\(completed) of \(total) tasks")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(AppTheme.surfaceContainerHigh, lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: trip.checklistProgress)
                        .stroke(progressColor.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(trip.checklistProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }

            // Urgent items warning
            let urgentCount = pendingItems.filter { $0.priority == .urgent }.count
            if urgentCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("\(urgentCount) urgent task\(urgentCount == 1 ? "" : "s") remaining")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(.top, 4)
            }

            // All done
            if trip.checklistProgress == 1.0 && !trip.checklistItems.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All tasks completed!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    private var progressColor: Color {
        if trip.checklistProgress == 1.0 { return .green }
        if trip.checklistProgress > 0.5 { return .blue }
        return .orange
    }

    // MARK: - Items Section

    private func itemsSection(title: String, items: [ChecklistItem], showPriority: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                Spacer()

                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppTheme.surfaceContainerHigh)
                    .clipShape(Capsule())
            }
            .padding()
            .background(AppTheme.surfaceContainerLow)

            VStack(spacing: 0) {
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
            .padding(.vertical, 4)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
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
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common Tasks")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .padding(.horizontal)

            VStack(spacing: 8) {
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
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
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
        .padding(.horizontal)
        .padding(.vertical, 10)
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task", text: $title)
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(ChecklistPriority.allCases, id: \.self) { p in
                            Label(p.displayName, systemImage: p.icon)
                                .tag(p)
                        }
                    }

                    Toggle("Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(item == nil ? "Add Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
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
        .presentationDetents([.medium])
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
