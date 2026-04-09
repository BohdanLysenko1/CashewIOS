import SwiftUI

struct TripPackingView: View {
    @Binding var trip: Trip
    let initialIntent: TripSectionIntent
    @State private var showAddItem = false
    @State private var editingItem: PackingItem?
    @State private var showUnpackedOnly = false
    @State private var didApplyInitialIntent = false

    init(trip: Binding<Trip>, initialIntent: TripSectionIntent = .overview) {
        self._trip = trip
        self.initialIntent = initialIntent
    }

    private var groupedItems: [PackingCategory: [PackingItem]] {
        Dictionary(grouping: trip.packingItems) { $0.category }
    }

    private var displayedItems: [PackingCategory: [PackingItem]] {
        if !showUnpackedOnly {
            return groupedItems
        }

        return groupedItems.compactMapValues { items in
            let remaining = items.filter { !$0.isPacked }
            return remaining.isEmpty ? nil : remaining
        }
    }

    private var displayedCategories: [PackingCategory] {
        displayedItems.keys.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.md) {
                progressCard

                TripSectionCard("View Options", icon: "line.3.horizontal.decrease.circle.fill") {
                    Toggle(isOn: $showUnpackedOnly) {
                        Text("Show unpacked only")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)
                    }
                    .tint(AppTheme.secondary)
                }

                if trip.packingItems.isEmpty {
                    emptyView
                } else {
                    if displayedCategories.isEmpty {
                        filteredEmptyView
                    } else {
                        ForEach(displayedCategories, id: \.self) { category in
                            categorySection(category: category, items: displayedItems[category] ?? [])
                        }
                    }
                }

                suggestionsCard
            }
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.vertical, AppTheme.Space.md)
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
        .onAppear {
            applyInitialIntentIfNeeded()
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        let packed = trip.packingItems.filter { $0.isPacked }.count
        let total = trip.packingItems.count

        return TripHeroCard(
            icon: "bag.fill",
            title: "Packing",
            subtitle: total == 0 ? "Start building your travel list" : "\(packed) of \(total) items ready"
        ) {
            HStack(spacing: AppTheme.Space.sm) {
                TripMetricPill(label: "Packed", value: "\(packed)")
                TripMetricPill(label: "Left", value: "\(max(0, total - packed))")
                TripMetricPill(label: "Progress", value: "\(Int(trip.packingProgress * 100))%")
            }

            AppProgressBar(progress: trip.packingProgress, color: progressColor)
                .frame(height: AppTheme.progressBarHeight)

            if trip.packingProgress == 1.0 && !trip.packingItems.isEmpty {
                Label("All packed and ready to go!", systemImage: "checkmark.circle.fill")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
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
        .padding(AppTheme.Space.lg)
        .tripModuleCard()
    }

    private var filteredEmptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("Everything is packed")
                .font(.headline)
                .foregroundStyle(AppTheme.onSurface)
            Text("No unpacked items left in this filter.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(AppTheme.Space.lg)
        .tripModuleCard()
    }

    // MARK: - Category Section

    private func categorySection(category: PackingCategory, items: [PackingItem]) -> some View {
        let packed = items.filter { $0.isPacked }.count
        return TripSectionCard(category.displayName, icon: category.icon) {
            HStack {
                Text("\(packed) packed of \(items.count)")
                    .font(AppTheme.TextStyle.secondary)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                Spacer()
                Text("\(Int((items.isEmpty ? 0 : (Double(packed) / Double(items.count))) * 100))%")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(category.color)
            }

            AppProgressBar(
                progress: items.isEmpty ? 0 : Double(packed) / Double(items.count),
                color: category.color
            )
            .frame(height: AppTheme.progressBarHeight)

            VStack(spacing: AppTheme.Space.xs) {
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
        }
    }

    // MARK: - Suggestions Card

    private var suggestionsCard: some View {
        TripSectionCard("Quick Add", icon: "sparkles") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Space.sm) {
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
                .padding(.horizontal, 2)
            }
        }
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

    private func applyInitialIntentIfNeeded() {
        guard !didApplyInitialIntent else { return }
        didApplyInitialIntent = true

        switch initialIntent {
        case .addPackingItem:
            showAddItem = true
        case .reviewPacking:
            showUnpackedOnly = true
        default:
            break
        }
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
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: item == nil ? "Add Item" : "Edit Item",
                subtitle: nil,
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    CreationSectionCard(title: "Item", icon: "bag") {
                        VStack(spacing: AppTheme.Space.sm) {
                            TextField("Item Name", text: $name)
                                .focused($nameFieldFocused)
                                .designField(isFocused: nameFieldFocused)

                            HStack {
                                Text("Quantity")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurface)
                                Spacer()
                                Stepper("\(quantity)", value: $quantity, in: 1...99)
                                    .fixedSize()
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    CreationSectionCard(title: "Category", icon: "tag") {
                        HStack {
                            Text("Category")
                                .font(AppTheme.TextStyle.body)
                                .foregroundStyle(AppTheme.onSurface)
                            Spacer()
                            Picker("Category", selection: $category) {
                                ForEach(PackingCategory.allCases, id: \.self) { cat in
                                    Label(cat.displayName, systemImage: cat.icon).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.secondary)
                        }
                        .padding(.horizontal, AppTheme.Space.md)
                        .padding(.vertical, AppTheme.Space.sm)
                        .background(AppTheme.surfaceContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                confirmTitle: item == nil ? "Add Item" : "Save Item",
                gradient: AppTheme.tripGradient,
                canConfirm: !name.isEmpty,
                isLoading: false,
                onCancel: { dismiss() },
                onConfirm: { saveItem(); dismiss() }
            )
        }
        .background(CreationScreenBackground(gradient: AppTheme.tripGradient))
        .presentationDetents([.medium])
        .onAppear {
            if let item {
                name = item.name
                quantity = item.quantity
                category = item.category
            }
        }
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
