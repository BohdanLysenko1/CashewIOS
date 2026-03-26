import SwiftUI

struct TripPackingView: View {
    @Binding var trip: Trip
    @State private var showAddItem = false
    @State private var editingItem: PackingItem?
    @State private var showCategoryPicker = false
    @State private var selectedCategory: PackingCategory?

    private var groupedItems: [PackingCategory: [PackingItem]] {
        Dictionary(grouping: trip.packingItems) { $0.category }
    }

    private var sortedCategories: [PackingCategory] {
        groupedItems.keys.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress Card
                progressCard

                // Items by Category
                if trip.packingItems.isEmpty {
                    emptyView
                } else {
                    ForEach(sortedCategories, id: \.self) { category in
                        categorySection(category: category, items: groupedItems[category] ?? [])
                    }
                }

                // Quick Add Suggestions
                suggestionsCard
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("Packing List")
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
            PackingItemFormView(trip: $trip, item: nil)
        }
        .sheet(item: $editingItem) { item in
            PackingItemFormView(trip: $trip, item: item)
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Packing Progress")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    let packed = trip.packingItems.filter { $0.isPacked }.count
                    let total = trip.packingItems.count

                    Text("\(packed) of \(total) items")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(AppTheme.surfaceContainerHigh, lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: trip.packingProgress)
                        .stroke(progressColor.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(trip.packingProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }

            if trip.packingProgress == 1.0 && !trip.packingItems.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All packed and ready to go!")
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
        if trip.packingProgress == 1.0 { return .green }
        if trip.packingProgress > 0.5 { return .blue }
        return .orange
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bag")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.onSurfaceVariant)

            VStack(spacing: 6) {
                Text("No Items Yet")
                    .font(.headline)

                Text("Start adding items to your packing list")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Button {
                showAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    // MARK: - Category Section

    private func categorySection(category: PackingCategory, items: [PackingItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                let packed = items.filter { $0.isPacked }.count
                Text("\(packed)/\(items.count)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
            .padding()
            .background(AppTheme.surfaceContainerLow)

            // Items
            VStack(spacing: 0) {
                ForEach(items.sorted(by: { !$0.isPacked && $1.isPacked })) { item in
                    PackingItemRow(item: item) {
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

    // MARK: - Suggestions Card

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickAddSuggestions, id: \.self) { suggestion in
                        Button {
                            addQuickItem(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.surfaceContainerLow)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    private var quickAddSuggestions: [String] {
        let existing = Set(trip.packingItems.map { $0.name.lowercased() })
        let suggestions = [
            "Passport", "Phone Charger", "Toothbrush", "Underwear",
            "Socks", "T-Shirts", "Pants", "Jacket", "Sunglasses",
            "Medications", "Laptop", "Camera", "Headphones"
        ]
        return suggestions.filter { !existing.contains($0.lowercased()) }
    }

    // MARK: - Actions

    private func toggleItem(_ item: PackingItem) {
        if let index = trip.packingItems.firstIndex(where: { $0.id == item.id }) {
            trip.packingItems[index].isPacked.toggle()
        }
    }

    private func deleteItem(_ item: PackingItem) {
        trip.packingItems.removeAll { $0.id == item.id }
    }

    private func addQuickItem(_ name: String) {
        let category = guessCategory(for: name)
        let item = PackingItem(name: name, category: category)
        trip.packingItems.append(item)
    }

    private func guessCategory(for name: String) -> PackingCategory {
        let lowercased = name.lowercased()
        if ["passport", "id", "visa", "ticket", "boarding pass"].contains(where: { lowercased.contains($0) }) {
            return .documents
        }
        if ["phone", "laptop", "charger", "camera", "headphones", "cable"].contains(where: { lowercased.contains($0) }) {
            return .electronics
        }
        if ["toothbrush", "shampoo", "soap", "deodorant", "razor"].contains(where: { lowercased.contains($0) }) {
            return .toiletries
        }
        if ["medication", "pills", "medicine", "first aid"].contains(where: { lowercased.contains($0) }) {
            return .medicine
        }
        if ["shirt", "pants", "jacket", "dress", "underwear", "socks", "shoes"].contains(where: { lowercased.contains($0) }) {
            return .clothing
        }
        if ["sunglasses", "watch", "jewelry", "belt", "hat"].contains(where: { lowercased.contains($0) }) {
            return .accessories
        }
        return .other
    }

}

// MARK: - Packing Item Row

private struct PackingItemRow: View {
    let item: PackingItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var checkScale: CGFloat = 1.0
    @State private var showConfetti = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                triggerToggle()
            } label: {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isPacked ? .green : AppTheme.onSurfaceVariant)
                    .scaleEffect(checkScale)
                    .symbolEffect(.bounce, value: item.isPacked)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .center) {
                if showConfetti {
                    ConfettiView()
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .strikethrough(item.isPacked)
                    .foregroundStyle(item.isPacked ? AppTheme.onSurfaceVariant : AppTheme.onSurface)

                if item.quantity > 1 {
                    Text("Qty: \(item.quantity)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
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

    private func triggerToggle() {
        let completing = !item.isPacked
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

// MARK: - Packing Item Form

struct PackingItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip

    let item: PackingItem?

    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var category: PackingCategory = .other

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item Name", text: $name)

                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(PackingCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(item == nil ? "Add Item" : "Edit Item")
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
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let item {
                    name = item.name
                    quantity = item.quantity
                    category = item.category
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveItem() {
        if let item {
            if let index = trip.packingItems.firstIndex(where: { $0.id == item.id }) {
                trip.packingItems[index].name = name
                trip.packingItems[index].quantity = quantity
                trip.packingItems[index].category = category
            }
        } else {
            let newItem = PackingItem(name: name, quantity: quantity, category: category)
            trip.packingItems.append(newItem)
        }
    }
}

#Preview {
    NavigationStack {
        TripPackingView(trip: .constant(Trip(
            name: "Paris Trip",
            destination: "Paris, France",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            packingItems: [
                PackingItem(name: "Passport", isPacked: true, category: .documents),
                PackingItem(name: "Phone Charger", category: .electronics),
                PackingItem(name: "T-Shirts", quantity: 5, category: .clothing),
                PackingItem(name: "Toothbrush", category: .toiletries)
            ]
        )))
    }
}
