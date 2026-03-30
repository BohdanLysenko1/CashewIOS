import SwiftUI

struct EventsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showAddEvent = false
    @State private var editingEvent: Event?
    @State private var searchText = ""
    @State private var selectedCategoryFilters: Set<EventCategory> = []
    @State private var isSelectMode = false
    @State private var selectedEvents: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showPast = false
    @State private var highlightedEventIds: Set<UUID> = []
    @State private var highlightDismissTasks: [UUID: Task<Void, Never>] = [:]

    private var eventService: EventServiceProtocol {
        container.eventService
    }

    private var filteredEvents: [Event] {
        var events = eventService.events

        if !selectedCategoryFilters.isEmpty {
            events = events.filter { selectedCategoryFilters.contains($0.category) }
        }

        if !searchText.isEmpty {
            events = events.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText)
            }
        }

        return events
    }

    private var upcomingEvents: [Event] {
        filteredEvents.filter { !$0.isPast }
    }

    private var pastEvents: [Event] {
        filteredEvents.filter { $0.isPast }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if isLoading {
                        ProgressView()
                    } else if let error {
                        errorView(error)
                    } else if eventService.events.isEmpty {
                        emptyView
                    } else if filteredEvents.isEmpty {
                        noResultsView
                    } else {
                        eventsList
                    }
                }

                if isSelectMode && !selectedEvents.isEmpty {
                    deleteBar
                }
            }
            .navigationTitle("Events")
            .searchable(text: $searchText, prompt: "Search events")
            .toolbar {
                if isSelectMode {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            withAnimation {
                                isSelectMode = false
                                selectedEvents.removeAll()
                            }
                        }
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        let visibleEvents = upcomingEvents + (showPast ? pastEvents : [])
                        Button(selectedEvents.count == visibleEvents.count ? "Deselect All" : "Select All") {
                            if selectedEvents.count == visibleEvents.count {
                                selectedEvents.removeAll()
                            } else {
                                selectedEvents = Set(visibleEvents.map(\.id))
                            }
                        }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddEvent = true
                        } label: {
                            Image(systemName: "plus")
                                .onGeometryChange(for: CGRect.self) { proxy in
                                    proxy.frame(in: .global)
                                } action: { frame in
                                    onboardingCoordinator.registerFrame(
                                        id: "anchor_events_toolbar",
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
            .fullScreenCover(isPresented: $showAddEvent) {
                EventCreationWizardView(
                    eventService: container.eventService,
                    onCreated: { _ in },
                    onDismiss: { showAddEvent = false }
                )
            }
            .fullScreenCover(item: $editingEvent) { event in
                EventFormView(
                    viewModel: EventFormViewModel(eventService: container.eventService, event: event)
                )
            }
            .confirmationDialog(
                "Delete \(selectedEvents.count) Event\(selectedEvents.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedEvents()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
        .task {
            await loadEvents()
        }
        .onChange(of: (container.eventService as? EventService)?.realtimeEventCounter ?? 0) { _, newValue in
            guard
                newValue > 0,
                let changedId = (container.eventService as? EventService)?.realtimeChangedEventId
            else { return }
            pulseEventRow(changedId)
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
        selectedCategoryFilters.count
    }

    private var categoryFilterSection: some View {
        AppFilterSection(
            title: "Filter Events",
            activeCount: activeFilterCount,
            onClear: { selectedCategoryFilters.removeAll() }
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Space.sm) {
                    AppFilterChip(
                        label: "All",
                        isSelected: selectedCategoryFilters.isEmpty,
                        tint: AppTheme.tertiary,
                        selectedGradient: AppTheme.eventGradient
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategoryFilters.removeAll()
                        }
                    }

                    ForEach(EventCategory.allCases, id: \.self) { category in
                        AppFilterChip(
                            label: category.displayName,
                            icon: category.icon,
                            isSelected: selectedCategoryFilters.contains(category),
                            tint: category.color,
                            selectedGradient: AppTheme.eventGradient
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedCategoryFilters.contains(category) {
                                    selectedCategoryFilters.remove(category)
                                } else {
                                    selectedCategoryFilters.insert(category)
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
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete \(selectedEvents.count) Event\(selectedEvents.count == 1 ? "" : "s")")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Views

    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.listSpacing) {
                if !isSelectMode {
                    categoryFilterSection
                        .padding(.bottom, AppTheme.Space.xs)
                }

                // Upcoming events
                ForEach(upcomingEvents) { event in
                    eventRow(event)
                }

                // Past section
                if !pastEvents.isEmpty {
                    pastSection
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .padding(.bottom, isSelectMode && !selectedEvents.isEmpty ? 70 : 0)
        }
        .background(AppTheme.background)
        .navigationDestination(for: UUID.self) { eventId in
            EventDetailView(eventId: eventId)
        }
        .refreshable {
            await loadEvents()
        }
    }

    @ViewBuilder
    private func eventRow(_ event: Event) -> some View {
        if isSelectMode {
            selectableEventRow(event)
        } else {
            liveHighlightedEventRow(event.id) {
                NavigationLink(value: event.id) {
                    EventCard(event: event)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        editingEvent = event
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        deleteEvent(event)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var pastSection: some View {
        VStack(spacing: AppTheme.listSpacing) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showPast.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    Text("Past Events")
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                    Text("\(pastEvents.count)")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .rotationEffect(.degrees(showPast ? 90 : 0))
                }
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            }
            .buttonStyle(.plain)

            if showPast {
                ForEach(pastEvents) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func selectableEventRow(_ event: Event) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selectedEvents.contains(event.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(selectedEvents.contains(event.id) ? AppTheme.primary : AppTheme.onSurfaceVariant)

            liveHighlightedEventRow(event.id) {
                EventCard(event: event)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                if selectedEvents.contains(event.id) {
                    selectedEvents.remove(event.id)
                } else {
                    selectedEvents.insert(event.id)
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle")
                .font(.system(size: 70))
                .foregroundStyle(AppTheme.eventGradient)

            VStack(spacing: 8) {
                Text("No Events")
                    .font(AppTheme.TextStyle.title)
                    .foregroundStyle(AppTheme.onSurface)

                Text("Create events to track your activities!")
                    .font(AppTheme.TextStyle.body)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddEvent = true
            } label: {
                Label("Create Event", systemImage: "plus")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var noResultsView: some View {
        VStack(spacing: AppTheme.Space.lg) {
            if !isSelectMode {
                categoryFilterSection
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
        } else if selectedCategoryFilters.count == 1, let category = selectedCategoryFilters.first {
            ContentUnavailableView(
                "No \(category.displayName) Events",
                systemImage: category.icon,
                description: Text("No events in this category")
            )
        } else if !selectedCategoryFilters.isEmpty {
            ContentUnavailableView(
                "No Matching Events",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("No events match your selected filters")
            )
        } else {
            ContentUnavailableView.search
        }
    }

    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Unable to Load Events", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry") {
                Task { await loadEvents() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func loadEvents() async {
        isLoading = eventService.events.isEmpty
        error = nil
        do {
            try await eventService.loadEvents()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func deleteEvent(_ event: Event) {
        Task {
            do {
                try await eventService.deleteEvent(by: event.id)
            } catch {
                self.error = error
            }
        }
    }

    private func deleteSelectedEvents() {
        let idsToDelete = selectedEvents
        Task {
            for id in idsToDelete {
                do {
                    try await eventService.deleteEvent(by: id)
                } catch {
                    self.error = error
                }
            }
            withAnimation {
                selectedEvents.removeAll()
                isSelectMode = false
            }
        }
    }

    @ViewBuilder
    private func liveHighlightedEventRow<Content: View>(_ id: UUID, @ViewBuilder content: () -> Content) -> some View {
        let isHighlighted = highlightedEventIds.contains(id)
        content()
            .scaleEffect(isHighlighted ? 1.015 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppTheme.tertiary.opacity(isHighlighted ? 0.92 : 0),
                                AppTheme.tertiary.opacity(isHighlighted ? 0.35 : 0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHighlighted ? 2 : 0
                    )
            )
            .shadow(color: AppTheme.tertiary.opacity(isHighlighted ? 0.30 : 0), radius: isHighlighted ? 16 : 0, x: 0, y: isHighlighted ? 8 : 0)
            .animation(.spring(response: 0.44, dampingFraction: 0.82), value: isHighlighted)
    }

    private func pulseEventRow(_ id: UUID) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
            _ = highlightedEventIds.insert(id)
        }

        highlightDismissTasks[id]?.cancel()
        highlightDismissTasks[id] = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.28)) {
                    _ = highlightedEventIds.remove(id)
                }
                highlightDismissTasks.removeValue(forKey: id)
            }
        }
    }
}

#Preview {
    EventsView()
        .environment(AppContainer())
        .environment(OnboardingCoordinator())
}
