import SwiftUI

struct TripDetailView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let tripId: UUID

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var error: String?
    @State private var showError = false
    @State private var shareURL: URL?
    @State private var isGeneratingShare = false
    @State private var showCollaborators = false
    @State private var showTripSummary = false
    @State private var revealContent = false
    @State private var weatherInfo: WeatherInfo?
    @State private var weatherLoading = false
    @State private var hasCollaborators = false
    private let weatherService = TripWeatherService()

    private var trip: Trip? {
        container.tripService.trip(by: tripId)
    }

    private var isOwner: Bool {
        guard let trip else { return false }
        guard let ownerId = trip.ownerId else { return true }
        return ownerId == container.authService.currentUser?.id
    }

    private var canEdit: Bool {
        trip != nil
    }

    private func shouldShowSharedByBanner(for trip: Trip) -> Bool {
        guard let ownerName = trip.ownerName, !ownerName.isEmpty else { return false }
        guard let ownerId = trip.ownerId, let currentUserId = container.authService.currentUser?.id else {
            return true
        }
        return ownerId != currentUserId
    }

    var body: some View {
        Group {
            if let trip {
                tripContent(trip)
            } else {
                ContentUnavailableView(
                    "Trip Not Found",
                    systemImage: "airplane.slash",
                    description: Text("This trip may have been deleted")
                )
            }
        }
        .navigationTitle(trip?.name ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if trip != nil {
                if canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await generateShareLink() }
                        } label: {
                            if isGeneratingShare {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(isGeneratingShare)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if canEdit {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }

                        Button {
                            showCollaborators = true
                        } label: {
                            Label("Manage Access", systemImage: "person.2")
                        }

                        if isOwner {
                            Divider()

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .fullScreenCover(isPresented: $showEditSheet) {
            if let trip {
                TripFormView(
                    viewModel: TripFormViewModel(
                        tripService: container.tripService,
                        trip: trip
                    )
                )
            }
        }
        .sheet(isPresented: .init(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let url = shareURL {
                let tripName = trip?.name ?? "a trip"
                ShareSheet(items: ["Join me on \(tripName) in Cashew — plan together in real time!", url])
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showCollaborators) {
            if let trip {
                CollaboratorsView(resource: .trip(trip))
            }
        }
        .confirmationDialog(
            "Delete Trip",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteTrip()
            }
        } message: {
            Text("Are you sure you want to delete this trip? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                error = nil
            }
        } message: {
            if let error {
                Text(error)
            }
        }
        .task(id: tripId) {
            guard isOwner, let trip else { return }
            let collaborators = (try? await container.shareService.fetchCollaborators(for: .trip(trip))) ?? []
            hasCollaborators = !collaborators.isEmpty
        }
        .sheet(isPresented: $showTripSummary) {
            if let trip { AITripSummaryView(trip: trip) }
        }
    }

    // MARK: - Content

    private func tripContent(_ trip: Trip) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.md) {
                if isOwner && hasCollaborators {
                    stagedCard(0) {
                        sharingActiveOwnerBanner
                    }
                } else if shouldShowSharedByBanner(for: trip), let name = trip.ownerName {
                    stagedCard(0) {
                        sharedByBanner(name: name, color: AppTheme.warning)
                    }
                }

                stagedCard(1) {
                    tripHero(trip)
                }

                if trip.destinationLatitude != nil {
                    stagedCard(2) {
                        TripWeatherCard(info: weatherInfo, isLoading: weatherLoading)
                    }
                }

                stagedCard(3) {
                    snapshotCard(trip)
                }

                stagedCard(4) {
                    nextActionsCard
                }

                stagedCard(5) {
                    quickActionsGrid(trip)
                }

                stagedCard(6) {
                    detailsCard(trip)
                }

                stagedCard(7) {
                    datesCard(trip)
                }

                stagedCard(8) {
                    resourcesCard(trip)
                }

                stagedCard(9) {
                    PhotosGridCard(attachments: trip.attachments, accentColor: AppTheme.primary)
                }

                if !trip.notes.isEmpty {
                    stagedCard(10) {
                        notesCard(trip)
                    }
                }

                stagedCard(11) {
                    linkedTasksCard(tripId: trip.id)
                }

                stagedCard(12) {
                    infoCard(trip)
                }
            }
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.vertical, AppTheme.Space.md)
            .onAppear {
                withAnimation(.spring(response: 0.50, dampingFraction: 0.86)) {
                    revealContent = true
                }
            }
        }
        .background(AppTheme.background)
        .task(id: trip.id) {
            guard let lat = trip.destinationLatitude,
                  let lon = trip.destinationLongitude else { return }
            weatherLoading = true
            weatherInfo = try? await weatherService.fetch(latitude: lat, longitude: lon)
            weatherLoading = false
        }
        .navigationDestination(for: TripRoute.self) { route in
            tripSectionView(route, trip: trip)
        }
    }

    // MARK: - Hero

    private func tripHero(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            HStack(alignment: .top, spacing: AppTheme.Space.md) {
                Image(systemName: "airplane")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.name)
                        .font(AppTheme.TextStyle.title)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    heroChip(icon: "mappin.and.ellipse", label: trip.destination)
                }

                Spacer(minLength: 0)
                StatusBadge(status: trip.computedStatus, style: .onGradient)
            }

            HStack(spacing: 8) {
                heroChip(icon: "calendar", label: trip.startDate.formatted(date: .abbreviated, time: .omitted))
                heroChip(icon: "airplane.arrival", label: trip.endDate.formatted(date: .abbreviated, time: .omitted))
                heroChip(icon: "clock.fill", label: durationText(from: trip.startDate, to: trip.endDate))
            }
        }
        .padding(AppTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.tripGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: AppTheme.secondary.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    private func heroChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(AppTheme.TextStyle.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.16))
        .clipShape(Capsule())
    }

    // MARK: - Snapshot + Actions

    private func snapshotCard(_ trip: Trip) -> some View {
        sectionCard("Trip Snapshot", icon: "sparkles") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Space.sm) {
                snapshotTile(
                    icon: "creditcard.fill",
                    title: "Budget",
                    value: budgetSubtitle(trip),
                    tint: AppTheme.positive
                )
                snapshotTile(
                    icon: "calendar.day.timeline.left",
                    title: "Itinerary",
                    value: "\(trip.activities.count) activities",
                    tint: AppTheme.primary
                )
                snapshotTile(
                    icon: "bag.fill",
                    title: "Packing",
                    value: packingSubtitle(trip),
                    tint: AppTheme.warning
                )
                snapshotTile(
                    icon: "checklist",
                    title: "Checklist",
                    value: checklistSubtitle(trip),
                    tint: AppTheme.tertiary
                )
            }
        }
    }

    private func snapshotTile(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(AppTheme.TextStyle.captionBold)
            }
            .foregroundStyle(tint)

            Text(value)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(AppTheme.onSurface)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var nextActionsCard: some View {
        sectionCard("Next Actions", icon: "bolt.fill") {
            VStack(spacing: AppTheme.Space.sm) {
                if trip?.activities.isEmpty == true {
                    actionLink(
                        title: "Generate AI Itinerary",
                        subtitle: "Create a personalized plan with Gemini",
                        icon: "sparkles",
                        tint: AppTheme.secondary,
                        route: TripRoute(section: .itinerary, intent: .generateAI)
                    )
                }
                actionLink(
                    title: "Add Itinerary Activity",
                    subtitle: "Drop the next stop into your timeline",
                    icon: "calendar.badge.plus",
                    tint: AppTheme.primary,
                    route: TripRoute(section: .itinerary, intent: .addActivity)
                )
                actionLink(
                    title: "Log New Expense",
                    subtitle: "Keep budget on track in real time",
                    icon: "creditcard.circle",
                    tint: AppTheme.positive,
                    route: TripRoute(section: .budget, intent: .addExpense)
                )
                actionLink(
                    title: "Review What Is Left to Pack",
                    subtitle: "Focus only on unpacked items",
                    icon: "bag.badge.questionmark",
                    tint: AppTheme.warning,
                    route: TripRoute(section: .packing, intent: .reviewPacking)
                )
                actionLink(
                    title: "Handle Priority Checklist Items",
                    subtitle: "Jump to urgent and high-priority tasks",
                    icon: "exclamationmark.circle",
                    tint: AppTheme.negative,
                    route: TripRoute(section: .checklist, intent: .reviewChecklist)
                )
            }
        }
    }

    private func actionLink(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        route: TripRoute
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                    Text(subtitle)
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Action Grid

    private func quickActionsGrid(_ trip: Trip) -> some View {
        sectionCard("Modules", icon: "square.grid.2x2.fill") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(value: TripRoute(section: .budget)) {
                    QuickActionCard(
                        icon: "creditcard.fill",
                        title: "Budget",
                        subtitle: budgetSubtitle(trip),
                        progress: trip.budgetProgress,
                        color: AppTheme.positive
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(value: TripRoute(section: .itinerary)) {
                    QuickActionCard(
                        icon: "calendar.day.timeline.left",
                        title: "Itinerary",
                        subtitle: "\(trip.activities.count) activities",
                        progress: nil,
                        color: AppTheme.primary
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(value: TripRoute(section: .packing)) {
                    QuickActionCard(
                        icon: "bag.fill",
                        title: "Packing",
                        subtitle: packingSubtitle(trip),
                        progress: trip.packingItems.isEmpty ? nil : trip.packingProgress,
                        color: AppTheme.warning
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(value: TripRoute(section: .checklist)) {
                    QuickActionCard(
                        icon: "checklist",
                        title: "Checklist",
                        subtitle: checklistSubtitle(trip),
                        progress: trip.checklistItems.isEmpty ? nil : trip.checklistProgress,
                        color: AppTheme.tertiary
                    )
                }
                .buttonStyle(.plain)

                Button { showTripSummary = true } label: {
                    QuickActionCard(
                        icon: "book.pages.fill",
                        title: "AI Journal",
                        subtitle: "Trip summary",
                        progress: nil,
                        color: AppTheme.secondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Detail Cards

    private func detailsCard(_ trip: Trip) -> some View {
        sectionCard("Details", icon: "info.circle") {
            VStack(spacing: 12) {
                if let lat = trip.destinationLatitude, let lng = trip.destinationLongitude {
                    Button {
                        MapLink.open(name: trip.destination, latitude: lat, longitude: lng)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.negative)
                                .frame(width: 24)
                            Text("Destination")
                                .font(AppTheme.TextStyle.body)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Spacer(minLength: 10)
                            Text(trip.destination)
                                .font(AppTheme.TextStyle.bodyBold)
                                .foregroundStyle(AppTheme.onSurface)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    detailLine(icon: "mappin.circle.fill", tint: AppTheme.negative, title: "Destination", value: trip.destination)
                }

                HStack {
                    Image(systemName: "flag.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 24)
                    Text("Status")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    Spacer()
                    StatusBadge(status: trip.computedStatus, style: .prominent)
                }
            }
        }
    }

    private func datesCard(_ trip: Trip) -> some View {
        sectionCard("Dates", icon: "calendar") {
            VStack(spacing: 12) {
                detailLine(
                    icon: "airplane.departure",
                    tint: AppTheme.positive,
                    title: "Start",
                    value: trip.startDate.formatted(date: .long, time: .omitted)
                )
                detailLine(
                    icon: "airplane.arrival",
                    tint: AppTheme.warning,
                    title: "End",
                    value: trip.endDate.formatted(date: .long, time: .omitted)
                )
                detailLine(
                    icon: "clock.fill",
                    tint: AppTheme.tertiary,
                    title: "Duration",
                    value: durationText(from: trip.startDate, to: trip.endDate)
                )
            }
        }
    }

    private func resourcesCard(_ trip: Trip) -> some View {
        sectionCard("Travel Notes", icon: "suitcase.rolling") {
            VStack(spacing: 12) {
                if !trip.accommodationName.isEmpty {
                    detailLine(
                        icon: "bed.double.fill",
                        tint: AppTheme.primary,
                        title: "Stay",
                        value: trip.accommodationName
                    )
                }
                if !trip.transportationType.isEmpty {
                    detailLine(
                        icon: "car.fill",
                        tint: AppTheme.secondary,
                        title: "Transport",
                        value: trip.transportationType
                    )
                }
                if !trip.accommodationConfirmation.isEmpty {
                    detailLine(
                        icon: "number.circle.fill",
                        tint: AppTheme.info,
                        title: "Hotel Confirmation",
                        value: trip.accommodationConfirmation
                    )
                }
                if !trip.transportationConfirmation.isEmpty {
                    detailLine(
                        icon: "ticket.fill",
                        tint: AppTheme.info,
                        title: "Transport Confirmation",
                        value: trip.transportationConfirmation
                    )
                }
                if trip.accommodationName.isEmpty &&
                    trip.transportationType.isEmpty &&
                    trip.accommodationConfirmation.isEmpty &&
                    trip.transportationConfirmation.isEmpty {
                    Text("No travel resource details yet.")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func notesCard(_ trip: Trip) -> some View {
        sectionCard("Notes", icon: "note.text") {
            Text(trip.notes)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(AppTheme.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func infoCard(_ trip: Trip) -> some View {
        sectionCard("Info", icon: "clock.arrow.circlepath") {
            VStack(spacing: 12) {
                detailLine(
                    icon: "plus.circle.fill",
                    tint: AppTheme.onSurfaceVariant,
                    title: "Created",
                    value: trip.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
                detailLine(
                    icon: "pencil.circle.fill",
                    tint: AppTheme.onSurfaceVariant,
                    title: "Updated",
                    value: trip.updatedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    // MARK: - Linked Tasks

    @ViewBuilder
    private func linkedTasksCard(tripId: UUID) -> some View {
        let linkedTasks = container.dayPlannerService.allTasks.filter { $0.tripId == tripId }

        if !linkedTasks.isEmpty {
            sectionCard("Linked Tasks", icon: "checklist") {
                VStack(spacing: AppTheme.Space.sm) {
                    ForEach(linkedTasks) { task in
                        HStack(spacing: 10) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(task.isCompleted ? .green : task.category.color)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(AppTheme.TextStyle.bodyBold)
                                    .strikethrough(task.isCompleted)
                                    .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)

                                Text(task.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(AppTheme.TextStyle.caption)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func tripSectionView(_ route: TripRoute, trip: Trip) -> some View {
        let tripBinding = Binding<Trip>(
            get: { container.tripService.trip(by: tripId) ?? trip },
            set: { newTrip in
                Task {
                    do {
                        try await container.tripService.updateTrip(newTrip)
                    } catch {
                        self.error = error.localizedDescription
                        showError = true
                    }
                }
            }
        )

        switch route.section {
        case .budget:
            TripBudgetView(trip: tripBinding, initialIntent: route.intent)
        case .itinerary:
            TripItineraryView(trip: tripBinding, initialIntent: route.intent)
        case .packing:
            TripPackingView(trip: tripBinding, initialIntent: route.intent)
        case .checklist:
            TripChecklistView(trip: tripBinding, initialIntent: route.intent)
        }
    }

    // MARK: - Shared Components

    private func sectionCard<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            SectionHeader(icon: icon, title: title, gradient: AppTheme.tripGradient)
            content()
        }
        .padding(AppTheme.Space.lg)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
        .shadow(color: AppTheme.cardShadow, radius: 16, x: 0, y: 6)
    }

    private func detailLine(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)

            Spacer(minLength: 10)

            Text(value)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(AppTheme.onSurface)
                .multilineTextAlignment(.trailing)
        }
    }

    private func stagedCard<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(revealContent ? 1 : 0)
            .offset(y: revealContent ? 0 : 14)
            .animation(
                .spring(response: 0.48, dampingFraction: 0.88).delay(Double(index) * 0.04),
                value: revealContent
            )
    }

    // MARK: - Formatting + Helpers

    private func budgetSubtitle(_ trip: Trip) -> String {
        if let budget = trip.budget {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = trip.currency
            formatter.maximumFractionDigits = 0
            return formatter.string(from: budget as NSNumber) ?? "\(trip.currency) \(budget)"
        }
        return "Not set"
    }

    private func packingSubtitle(_ trip: Trip) -> String {
        if trip.packingItems.isEmpty {
            return "No items"
        }
        let packed = trip.packingItems.filter { $0.isPacked }.count
        return "\(packed)/\(trip.packingItems.count) packed"
    }

    private func checklistSubtitle(_ trip: Trip) -> String {
        if trip.checklistItems.isEmpty {
            return "No tasks"
        }
        let done = trip.checklistItems.filter { $0.isCompleted }.count
        return "\(done)/\(trip.checklistItems.count) done"
    }

    private var sharingActiveOwnerBanner: some View {
        HStack(spacing: AppTheme.Space.sm) {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.primary)
            Text("You're sharing this trip")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.primary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.primary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sharedByBanner(name: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Space.sm) {
            Image(systemName: "person.fill.checkmark")
                .font(.caption)
                .foregroundStyle(color)
            Text("Shared by \(name)")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func durationText(from start: Date, to end: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        if days == 0 {
            return "1 day"
        } else if days == 1 {
            return "2 days"
        } else {
            return "\(days + 1) days"
        }
    }

    private func generateShareLink() async {
        guard let trip else { return }
        guard container.dataSyncService.isEnabled else {
            error = "Enable CashewCloud in Settings to share trips."
            showError = true
            return
        }
        isGeneratingShare = true
        do {
            shareURL = try await container.shareService.createInviteLink(for: .trip(trip))
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        isGeneratingShare = false
    }

    private func deleteTrip() {
        isDeleting = true
        Task {
            do {
                try await container.tripService.deleteTrip(by: tripId)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                showError = true
            }
            isDeleting = false
        }
    }
}

// MARK: - Quick Action Card

private struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let progress: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            bottomIndicator
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(AppTheme.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var bottomIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.surfaceContainerHigh)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(color.gradient)
                    .frame(
                        width: geometry.size.width * progressWidth,
                        height: 6
                    )
            }
        }
        .frame(height: 6)
        .opacity(progress == nil ? 0.35 : 1)
    }

    private var progressWidth: Double {
        if let progress {
            return min(max(progress, 0), 1)
        }
        return 0.22
    }
}

#Preview {
    NavigationStack {
        TripDetailView(tripId: UUID())
            .environment(AppContainer())
    }
}
