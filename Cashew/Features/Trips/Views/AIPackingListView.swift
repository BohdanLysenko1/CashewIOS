import SwiftUI

// MARK: - ViewModel

@Observable
final class AIPackingListViewModel {

    enum Phase {
        case configure
        case loading
        case review(AIPackingListResponse)
        case error(String)
    }

    var phase: Phase = .configure
    var selectedItems: Set<String> = [] // "category:name" keys
    var travelerCount = 1
    var preferences: Set<String> = []   // e.g. "carry-on only", "warm weather"

    private let service: AIPackingListServiceProtocol
    let trip: Trip

    init(trip: Trip, service: AIPackingListServiceProtocol = AIPackingListService()) {
        self.trip = trip
        self.service = service
    }

    let availablePreferences: [String] = [
        "Carry-on only", "Checked luggage OK",
        "Formal events", "Outdoor adventure",
        "Beach vacation", "Business trip",
        "Cold weather", "Warm weather"
    ]

    var reviewCategories: [AIPackingCategory] {
        guard case .review(let response) = phase else { return [] }
        return response.categories
    }

    var selectedCount: Int { selectedItems.count }

    func itemKey(_ category: String, _ name: String) -> String { "\(category):\(name)" }

    func toggleItem(_ category: String, _ item: AIPackingItem) {
        let key = itemKey(category, item.name)
        if selectedItems.contains(key) { selectedItems.remove(key) }
        else { selectedItems.insert(key) }
    }

    func isItemSelected(_ category: String, _ item: AIPackingItem) -> Bool {
        selectedItems.contains(itemKey(category, item.name))
    }

    func selectAll() {
        for cat in reviewCategories {
            for item in cat.items {
                selectedItems.insert(itemKey(cat.category, item.name))
            }
        }
    }

    func selectEssentials() {
        selectedItems.removeAll()
        for cat in reviewCategories {
            for item in cat.items where item.essential {
                selectedItems.insert(itemKey(cat.category, item.name))
            }
        }
    }

    @MainActor
    func generate() async {
        phase = .loading

        let durationDays = max(1, Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 1)

        let request = AIPackingListRequest(
            destination: trip.destination,
            tripDurationDays: durationDays,
            activities: trip.activities.map(\.title),
            interests: [],
            weatherSummary: nil,
            travelerCount: travelerCount,
            preferences: Array(preferences)
        )

        do {
            let response = try await service.generatePackingList(request: request)
            // Auto-select all items
            for cat in response.categories {
                for item in cat.items {
                    selectedItems.insert(itemKey(cat.category, item.name))
                }
            }
            phase = .review(response)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func buildPackingItems() -> [PackingItem] {
        reviewCategories.flatMap { cat in
            cat.toPackingItems().filter { selectedItems.contains(itemKey(cat.category, $0.name)) }
        }
    }
}

// MARK: - View

struct AIPackingListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip
    @State private var viewModel: AIPackingListViewModel

    init(trip: Binding<Trip>, viewModel: AIPackingListViewModel? = nil) {
        self._trip = trip
        self._viewModel = State(initialValue: viewModel ?? AIPackingListViewModel(trip: trip.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                switch viewModel.phase {
                case .configure:
                    configurePhase
                case .loading:
                    loadingPhase
                case .review:
                    reviewPhase
                case .error(let message):
                    errorPhase(message)
                }
            }
            .navigationTitle("AI Packing List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Configure

    private var configurePhase: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.lg) {
                TripSectionCard("Trip Info", icon: "suitcase.fill") {
                    VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                        Text(trip.destination)
                            .font(AppTheme.TextStyle.body)
                        let days = max(1, Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 1)
                        Text("\(days) day\(days == 1 ? "" : "s")")
                            .font(AppTheme.TextStyle.secondary)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }

                TripSectionCard("Travelers", icon: "person.2.fill") {
                    Stepper("Travelers: \(viewModel.travelerCount)", value: $viewModel.travelerCount, in: 1...10)
                        .font(AppTheme.TextStyle.body)
                }

                TripSectionCard("Preferences", icon: "slider.horizontal.3") {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: AppTheme.Space.sm
                    ) {
                        ForEach(viewModel.availablePreferences, id: \.self) { pref in
                            let isSelected = viewModel.preferences.contains(pref)
                            Button {
                                if isSelected { viewModel.preferences.remove(pref) }
                                else { viewModel.preferences.insert(pref) }
                            } label: {
                                Text(pref)
                                    .font(AppTheme.TextStyle.captionBold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? AnyShapeStyle(AppTheme.tripGradient) : AnyShapeStyle(AppTheme.surfaceContainerLow))
                                    .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    Task { await viewModel.generate() }
                } label: {
                    Label("Generate Packing List", systemImage: "sparkles")
                        .primaryActionButton(gradient: AppTheme.tripGradient)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppTheme.Space.lg)
            }
            .padding(.vertical, AppTheme.Space.lg)
        }
    }

    // MARK: - Loading

    private var loadingPhase: some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Generating your packing list...")
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
            Spacer()
        }
    }

    // MARK: - Review

    private var reviewPhase: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.Space.lg) {
                    HStack {
                        Button("Select All") { viewModel.selectAll() }
                        Spacer()
                        Button("Essentials Only") { viewModel.selectEssentials() }
                    }
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, AppTheme.Space.lg)

                    ForEach(viewModel.reviewCategories) { cat in
                        let packCat = PackingCategory(rawValue: cat.category) ?? .other
                        TripSectionCard(packCat.displayName, icon: packCat.icon) {
                            VStack(spacing: AppTheme.Space.sm) {
                                ForEach(cat.items) { item in
                                    let selected = viewModel.isItemSelected(cat.category, item)
                                    Button {
                                        viewModel.toggleItem(cat.category, item)
                                    } label: {
                                        HStack {
                                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selected ? AppTheme.primary : AppTheme.onSurfaceVariant)
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text(item.name)
                                                        .font(AppTheme.TextStyle.body)
                                                        .foregroundStyle(AppTheme.onSurface)
                                                    if item.essential {
                                                        Text("Essential")
                                                            .font(AppTheme.TextStyle.micro)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(AppTheme.warning.opacity(0.2))
                                                            .foregroundStyle(AppTheme.warning)
                                                            .clipShape(Capsule())
                                                    }
                                                }
                                                Text("Qty: \(item.quantity)")
                                                    .font(AppTheme.TextStyle.caption)
                                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, AppTheme.Space.lg)
            }

            // Bottom bar
            VStack(spacing: AppTheme.Space.sm) {
                Button {
                    addSelectedItems()
                } label: {
                    Text("Add \(viewModel.selectedCount) Items to Trip")
                        .primaryActionButton(gradient: AppTheme.tripGradient)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedCount == 0)
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.top, AppTheme.Space.sm)
                .padding(.bottom, AppTheme.Space.md)
            }
            .background(AppTheme.background)
        }
    }

    // MARK: - Error

    private func errorPhase(_ message: String) -> some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.negative)
            Text(message)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                viewModel.phase = .configure
            } label: {
                Text("Try Again")
                    .primaryActionButton(gradient: AppTheme.tripGradient)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.Space.xl)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func addSelectedItems() {
        let newItems = viewModel.buildPackingItems()
        trip.packingItems.append(contentsOf: newItems)
        dismiss()
    }
}
