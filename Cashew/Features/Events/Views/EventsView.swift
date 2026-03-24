import SwiftUI

struct EventsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showAddEvent = false
    @State private var editingEvent: Event?
    @State private var searchText = ""
    @State private var selectedCategoryFilter: EventCategory?
    @State private var isSelectMode = false
    @State private var selectedEvents: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showPast = false

    private var eventService: EventServiceProtocol {
        container.eventService
    }

    private var filteredEvents: [Event] {
        var events = eventService.events

        if let category = selectedCategoryFilter {
            events = events.filter { $0.category == category }
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

                    ToolbarItem(placement: .secondaryAction) {
                        filterMenu
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) {
                EventFormView(
                    viewModel: EventFormViewModel(eventService: container.eventService)
                )
            }
            .sheet(item: $editingEvent) { event in
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

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            Button {
                selectedCategoryFilter = nil
            } label: {
                HStack {
                    Text("All Categories")
                    if selectedCategoryFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(EventCategory.allCases, id: \.self) { category in
                Button {
                    selectedCategoryFilter = category
                } label: {
                    HStack {
                        Label(category.displayName, systemImage: category.icon)
                        if selectedCategoryFilter == category {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: selectedCategoryFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
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

            EventCard(event: event)
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

    @ViewBuilder
    private var noResultsView: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if let category = selectedCategoryFilter {
            ContentUnavailableView(
                "No \(category.displayName) Events",
                systemImage: category.icon,
                description: Text("No events in this category")
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
}

#Preview {
    EventsView()
        .environment(AppContainer())
        .environment(OnboardingCoordinator())
}
