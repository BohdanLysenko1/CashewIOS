import SwiftUI

struct TripsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showAddTrip = false
    @State private var editingTrip: Trip?
    @State private var searchText = ""
    @State private var selectedStatusFilters: Set<TripStatus> = []
    @State private var isSelectMode = false
    @State private var selectedTrips: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var tripToDelete: Trip?
    @State private var showCompleted = false
    @State private var highlightedTripIds: Set<UUID> = []
    @State private var highlightDismissTasks: [UUID: Task<Void, Never>] = [:]
    @State private var sharedByMeTripIds: Set<UUID> = []

    private var tripService: TripServiceProtocol {
        container.tripService
    }

    private var filteredTrips: [Trip] {
        var trips = tripService.trips

        if !selectedStatusFilters.isEmpty {
            trips = trips.filter { selectedStatusFilters.contains($0.computedStatus) }
        }

        if !searchText.isEmpty {
            trips = trips.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.destination.localizedCaseInsensitiveContains(searchText)
            }
        }

        return trips
    }

    private var activeTrips: [Trip] {
        filteredTrips.filter { $0.computedStatus != .completed && $0.computedStatus != .cancelled }
    }

    private var completedTrips: [Trip] {
        filteredTrips.filter { $0.computedStatus == .completed }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if isLoading {
                        ProgressView()
                    } else if let error {
                        errorView(error)
                    } else if tripService.trips.isEmpty {
                        emptyView
                    } else if filteredTrips.isEmpty {
                        noResultsView
                    } else {
                        tripsList
                    }
                }

                if isSelectMode && !selectedTrips.isEmpty {
                    deleteBar
                }
            }
            .navigationTitle("Trips")
            .searchable(text: $searchText, prompt: "Search trips")
            .toolbar {
                if isSelectMode {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            withAnimation {
                                isSelectMode = false
                                selectedTrips.removeAll()
                            }
                        }
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        let visibleTrips = activeTrips + (showCompleted ? completedTrips : [])
                        Button(selectedTrips.count == visibleTrips.count ? "Deselect All" : "Select All") {
                            if selectedTrips.count == visibleTrips.count {
                                selectedTrips.removeAll()
                            } else {
                                selectedTrips = Set(visibleTrips.map(\.id))
                            }
                        }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddTrip = true
                        } label: {
                            Image(systemName: "plus")
                                .onGeometryChange(for: CGRect.self) { proxy in
                                    proxy.frame(in: .global)
                                } action: { frame in
                                    onboardingCoordinator.registerFrame(
                                        id: "anchor_trips_toolbar",
                                        frame: frame
                                    )
                                }
                        }
                    }

                    ToolbarItem(placement: .secondaryAction) {
                        selectButton
                    }
                }
            }
            .fullScreenCover(isPresented: $showAddTrip) {
                TripCreationWizardView(
                    tripService: container.tripService,
                    onCreated: { _ in },
                    onDismiss: { showAddTrip = false }
                )
            }
            .fullScreenCover(item: $editingTrip) { trip in
                TripFormView(
                    viewModel: TripFormViewModel(tripService: container.tripService, trip: trip)
                )
            }
            .confirmationDialog(
                "Delete \(selectedTrips.count) Trip\(selectedTrips.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedTrips()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .confirmationDialog(
                "Delete Trip?",
                isPresented: Binding(
                    get: { tripToDelete != nil },
                    set: { if !$0 { tripToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let trip = tripToDelete {
                        deleteTrip(trip)
                        tripToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(tripToDelete?.name ?? "this trip")\"? This action cannot be undone.")
            }
        }
        .task {
            await loadTrips()
        }
        .onChange(of: (container.tripService as? TripService)?.realtimeEventCounter ?? 0) { _, newValue in
            guard
                newValue > 0,
                let changedId = (container.tripService as? TripService)?.realtimeChangedTripId
            else { return }
            pulseTripRow(changedId)
        }
        .onDisappear {
            for task in highlightDismissTasks.values {
                task.cancel()
            }
            highlightDismissTasks.removeAll()
        }
    }

    // MARK: - Select Button

    private var selectButton: some View {
        Button {
            withAnimation {
                isSelectMode = true
            }
        } label: {
            Label("Select", systemImage: "checkmark.circle")
        }
    }

    // MARK: - Filters

    private var activeFilterCount: Int {
        selectedStatusFilters.count
    }

    private var statusFilterSection: some View {
        AppFilterSection(
            title: "Filter Trips",
            activeCount: activeFilterCount,
            onClear: { selectedStatusFilters.removeAll() }
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Space.sm) {
                    AppFilterChip(
                        label: "All",
                        isSelected: selectedStatusFilters.isEmpty,
                        tint: AppTheme.secondary,
                        selectedGradient: AppTheme.tripGradient
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatusFilters.removeAll()
                        }
                    }

                    ForEach(TripStatus.allCases, id: \.self) { status in
                        AppFilterChip(
                            label: status.displayName,
                            icon: status.icon,
                            isSelected: selectedStatusFilters.contains(status),
                            tint: status.color,
                            selectedGradient: AppTheme.tripGradient
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedStatusFilters.contains(status) {
                                    selectedStatusFilters.remove(status)
                                } else {
                                    selectedStatusFilters.insert(status)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Delete Bar

    private var deleteBar: some View {
        DestructiveSelectionBar(
            title: "Delete \(selectedTrips.count) Trip\(selectedTrips.count == 1 ? "" : "s")"
        ) {
            showDeleteConfirmation = true
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Views

    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.listSpacing) {
                if !isSelectMode {
                    tripsOverviewCard
                }

                if !isSelectMode {
                    statusFilterSection
                        .padding(.bottom, AppTheme.Space.xs)
                }

                // Active trips
                ForEach(activeTrips) { trip in
                    tripRow(trip)
                }

                // Completed section
                if !completedTrips.isEmpty {
                    completedSection
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .padding(.bottom, isSelectMode && !selectedTrips.isEmpty ? 70 : 0)
        }
        .background(AppTheme.background)
        .navigationDestination(for: UUID.self) { tripId in
            TripDetailView(tripId: tripId)
        }
        .refreshable {
            await loadTrips()
        }
    }

    private var tripsOverviewCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            SectionHeader(icon: "airplane", title: "Travel Dashboard", gradient: AppTheme.tripGradient)

            let upcoming = filteredTrips.filter { $0.computedStatus == .upcoming }.count
            let active = filteredTrips.filter { $0.computedStatus == .active }.count
            let completed = filteredTrips.filter { $0.computedStatus == .completed }.count

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Space.sm) {
                overviewTile(title: "Upcoming", value: "\(upcoming)", tint: AppTheme.primary, icon: "calendar.badge.plus")
                overviewTile(title: "Active", value: "\(active)", tint: AppTheme.positive, icon: "location.north.line")
                overviewTile(title: "Completed", value: "\(completed)", tint: AppTheme.onSurfaceVariant, icon: "checkmark.circle")
            }
        }
        .padding(AppTheme.Space.lg)
        .tripModuleCard()
    }

    private func overviewTile(title: String, value: String, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
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
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func tripRow(_ trip: Trip) -> some View {
        if isSelectMode {
            selectableTripRow(trip)
        } else {
            liveHighlightedTripRow(trip.id) {
                NavigationLink(value: trip.id) {
                    TripCard(
                        trip: trip,
                        currentUserId: container.authService.currentUser?.id,
                        isSharedByMe: sharedByMeTripIds.contains(trip.id)
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        editingTrip = trip
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        tripToDelete = trip
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(spacing: AppTheme.listSpacing) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showCompleted.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    Text("Completed")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(completedTrips.count)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .rotationEffect(.degrees(showCompleted ? 90 : 0))
                }
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .padding()
                .tripModuleCard()
            }
            .buttonStyle(.plain)

            if showCompleted {
                ForEach(completedTrips) { trip in
                    tripRow(trip)
                }
            }
        }
    }

    private func selectableTripRow(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selectedTrips.contains(trip.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(selectedTrips.contains(trip.id) ? AppTheme.primary : AppTheme.onSurfaceVariant)

            liveHighlightedTripRow(trip.id) {
                TripCard(
                    trip: trip,
                    currentUserId: container.authService.currentUser?.id,
                    isSharedByMe: sharedByMeTripIds.contains(trip.id)
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                if selectedTrips.contains(trip.id) {
                    selectedTrips.remove(trip.id)
                } else {
                    selectedTrips.insert(trip.id)
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 70))
                .foregroundStyle(AppTheme.tripGradient)

            VStack(spacing: 8) {
                Text("No Trips Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Start planning your next adventure!")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddTrip = true
            } label: {
                Label("Plan a Trip", systemImage: "plus")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .tripModuleCard()
    }

    private var noResultsView: some View {
        VStack(spacing: AppTheme.Space.lg) {
            if !isSelectMode {
                statusFilterSection
            }
            noResultsContent
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var noResultsContent: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if selectedStatusFilters.count == 1, let status = selectedStatusFilters.first {
            ContentUnavailableView(
                "No \(status.displayName) Trips",
                systemImage: "airplane",
                description: Text("No trips with this status")
            )
        } else if !selectedStatusFilters.isEmpty {
            ContentUnavailableView(
                "No Matching Trips",
                systemImage: "airplane",
                description: Text("No trips match your selected filters")
            )
        } else {
            ContentUnavailableView.search
        }
    }

    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Unable to Load Trips", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry") {
                Task { await loadTrips() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func loadTrips() async {
        isLoading = tripService.trips.isEmpty
        error = nil
        do {
            try await tripService.loadTrips()
            if let ids = try? await container.shareService.fetchSharedTripIds() {
                sharedByMeTripIds = ids
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func deleteTrip(_ trip: Trip) {
        Task {
            do {
                try await tripService.deleteTrip(by: trip.id)
            } catch {
                self.error = error
            }
        }
    }

    private func deleteSelectedTrips() {
        let idsToDelete = selectedTrips
        Task {
            for id in idsToDelete {
                do {
                    try await tripService.deleteTrip(by: id)
                } catch {
                    self.error = error
                }
            }
            withAnimation {
                selectedTrips.removeAll()
                isSelectMode = false
            }
        }
    }

    @ViewBuilder
    private func liveHighlightedTripRow<Content: View>(_ id: UUID, @ViewBuilder content: () -> Content) -> some View {
        let isHighlighted = highlightedTripIds.contains(id)
        content()
            .scaleEffect(isHighlighted ? 1.015 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppTheme.warning.opacity(isHighlighted ? 0.92 : 0),
                                AppTheme.warning.opacity(isHighlighted ? 0.35 : 0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHighlighted ? 2 : 0
                    )
            )
            .shadow(color: AppTheme.warning.opacity(isHighlighted ? 0.30 : 0), radius: isHighlighted ? 16 : 0, x: 0, y: isHighlighted ? 8 : 0)
            .animation(.spring(response: 0.44, dampingFraction: 0.82), value: isHighlighted)
    }

    private func pulseTripRow(_ id: UUID) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
            _ = highlightedTripIds.insert(id)
        }

        highlightDismissTasks[id]?.cancel()
        highlightDismissTasks[id] = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.28)) {
                    _ = highlightedTripIds.remove(id)
                }
                highlightDismissTasks.removeValue(forKey: id)
            }
        }
    }
}

#Preview {
    TripsView()
        .environment(AppContainer())
        .environment(OnboardingCoordinator())
}
