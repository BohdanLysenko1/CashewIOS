import SwiftUI
import MapKit

// MARK: - ViewModel

@Observable
final class AIItineraryViewModel {

    enum Phase {
        case configure
        case loading
        case review([AIActivity])
        case error(String)
        case noBudget
    }

    // Configure state
    var selectedInterests: Set<String> = []
    var budgetAllocationString: String = ""

    // Review state
    var phase: Phase = .configure
    var selectedIDs: Set<String> = []
    var selectedMapDay: String? = nil  // "YYYY-MM-DD" or nil = show all days

    private let service: AIItineraryServiceProtocol
    let trip: Trip

    init(trip: Trip, service: AIItineraryServiceProtocol = AIItineraryService()) {
        self.trip = trip
        self.service = service
        // Pre-fill allocation from remaining budget, else total budget
        if let remaining = trip.remainingBudget, remaining > 0 {
            budgetAllocationString = "\(NSDecimalNumber(decimal: remaining).doubleValue)"
        } else if let budget = trip.budget {
            budgetAllocationString = "\(NSDecimalNumber(decimal: budget).doubleValue)"
        }
    }

    // MARK: - Computed

    var hasBudget: Bool { trip.budget != nil }
    var budgetAllocation: Double { Double(budgetAllocationString) ?? 0 }
    var canGenerate: Bool { !selectedInterests.isEmpty && budgetAllocation > 0 }

    let availableInterests: [String] = [
        "restaurant", "museum", "tour", "beach",
        "hiking", "shopping", "nightlife", "activity"
    ]

    var reviewActivities: [AIActivity] {
        guard case .review(let a) = phase else { return [] }
        return a
    }

    var activitiesByDay: [(date: String, items: [AIActivity])] {
        let base = selectedMapDay.map { day in reviewActivities.filter { $0.date == day } }
            ?? reviewActivities
        let grouped = Dictionary(grouping: base) { $0.date }
        return grouped.keys.sorted().map { d in
            (date: d, items: grouped[d]!.sorted { ($0.startTime ?? "") < ($1.startTime ?? "") })
        }
    }

    var visibleMapActivities: [AIActivity] {
        let base = selectedMapDay.map { day in reviewActivities.filter { $0.date == day } }
            ?? reviewActivities
        return base.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var selectedCount: Int { selectedIDs.count }

    // MARK: - Actions

    func toggleInterest(_ i: String) {
        if selectedInterests.contains(i) { selectedInterests.remove(i) }
        else { selectedInterests.insert(i) }
    }

    func toggleActivity(_ a: AIActivity) {
        if selectedIDs.contains(a.id) { selectedIDs.remove(a.id) }
        else { selectedIDs.insert(a.id) }
    }

    func selectAll() {
        selectedIDs = Set(reviewActivities.map(\.id))
    }

    @MainActor
    func generate() async {
        phase = .loading
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let request = AIItineraryRequest(
            destination: trip.destination,
            destinationLatitude: trip.destinationLatitude,
            destinationLongitude: trip.destinationLongitude,
            startDate: fmt.string(from: trip.startDate),
            endDate: fmt.string(from: trip.endDate),
            tripCurrency: trip.currency,
            budgetAllocation: budgetAllocation,
            interests: Array(selectedInterests),
            existingActivityTitles: trip.activities.map(\.title)
        )

        do {
            let response = try await service.generateItinerary(request: request)
            selectedIDs = Set(response.activities.map(\.id))
            phase = .review(response.activities)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func buildSelectedActivities() -> [Activity] {
        reviewActivities
            .filter { selectedIDs.contains($0.id) }
            .map { $0.toActivity(tripStartDate: trip.startDate, tripCurrency: trip.currency) }
    }
}

// MARK: - Main View

struct AIItineraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip
    @State private var viewModel: AIItineraryViewModel
    let onGoToBudget: () -> Void

    init(trip: Binding<Trip>, onGoToBudget: @escaping () -> Void) {
        _trip = trip
        _viewModel = State(initialValue: AIItineraryViewModel(trip: trip.wrappedValue))
        self.onGoToBudget = onGoToBudget
    }

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: "AI Itinerary",
                subtitle: "Powered by Gemini",
                onClose: { dismiss() }
            )

            Group {
                switch viewModel.phase {
                case .configure:
                    configurePhase
                case .loading:
                    loadingPhase
                case .review:
                    reviewPhase
                case .error(let message):
                    errorPhase(message)
                case .noBudget:
                    noBudgetPhase
                }
            }
        }
        .background(CreationScreenBackground(gradient: AppTheme.tripGradient))
        .onAppear {
            if !viewModel.hasBudget {
                viewModel.phase = .noBudget
            }
        }
    }

    // MARK: - Configure Phase

    private var configurePhase: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.md) {

                // Budget allocation
                CreationSectionCard(title: "Activity Budget", icon: "creditcard") {
                    VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                        HStack(spacing: AppTheme.Space.sm) {
                            Text(trip.currency)
                                .font(AppTheme.TextStyle.body)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                                .padding(.leading, 14)
                            TextField("Amount to allocate", text: $viewModel.budgetAllocationString)
                                .keyboardType(.decimalPad)
                        }
                        .padding(.vertical, 14)
                        .background(AppTheme.surfaceContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if let remaining = trip.remainingBudget {
                            Text("Remaining trip budget: \(trip.currency) \(NSDecimalNumber(decimal: remaining).doubleValue, specifier: "%.2f")")
                                .font(AppTheme.TextStyle.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }
                }

                // Interests
                CreationSectionCard(title: "Your Interests", icon: "heart") {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: AppTheme.Space.sm
                    ) {
                        ForEach(viewModel.availableInterests, id: \.self) { interest in
                            let isSelected = viewModel.selectedInterests.contains(interest)
                            let category = ActivityCategory(rawValue: interest) ?? .activity

                            Button {
                                viewModel.toggleInterest(interest)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 20))
                                    Text(category.displayName)
                                        .font(AppTheme.TextStyle.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
                                .background(
                                    isSelected
                                        ? AnyShapeStyle(AppTheme.tripGradient)
                                        : AnyShapeStyle(AppTheme.surfaceContainer)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            isSelected
                                                ? Color.white.opacity(0.3)
                                                : AppTheme.outlineVariant,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.top, AppTheme.Space.md)
            .padding(.bottom, AppTheme.Space.xxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Cancel",
                confirmTitle: "Generate",
                gradient: AppTheme.tripGradient,
                canConfirm: viewModel.canGenerate,
                isLoading: false,
                onCancel: { dismiss() },
                onConfirm: { Task { await viewModel.generate() } }
            )
        }
    }

    // MARK: - Loading Phase

    private var loadingPhase: some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(AppTheme.secondary)
            Text("Gemini is crafting your itinerary...")
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Space.lg)
    }

    // MARK: - Review Phase

    private var reviewPhase: some View {
        VStack(spacing: 0) {
            // Map
            AIItineraryMapView(activities: viewModel.visibleMapActivities)
                .frame(height: 260)

            // Day filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Space.sm) {
                    dayFilterPill(date: nil, label: "All Days")
                    ForEach(viewModel.activitiesByDay, id: \.date) { group in
                        dayFilterPill(date: group.date, label: formattedDayLabel(group.date))
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.sm)
            }
            .background(AppTheme.background)

            // Activity list
            ScrollView {
                VStack(spacing: AppTheme.Space.sm) {
                    HStack {
                        Text("\(viewModel.selectedCount) selected")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        Spacer()
                        Button("Select All") { viewModel.selectAll() }
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(AppTheme.secondary)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.top, AppTheme.Space.sm)

                    ForEach(viewModel.activitiesByDay, id: \.date) { group in
                        TripSectionCard(formattedDayLabel(group.date), icon: "calendar") {
                            VStack(spacing: AppTheme.Space.sm) {
                                ForEach(group.items) { activity in
                                    AIActivityRow(
                                        activity: activity,
                                        isSelected: viewModel.selectedIDs.contains(activity.id),
                                        onToggle: { viewModel.toggleActivity(activity) }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.lg)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(AppTheme.background)
        }
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Discard",
                confirmTitle: "Add \(viewModel.selectedCount) to Trip",
                gradient: AppTheme.tripGradient,
                canConfirm: viewModel.selectedCount > 0,
                isLoading: false,
                onCancel: { viewModel.phase = .configure },
                onConfirm: { addToTrip() }
            )
        }
    }

    private func dayFilterPill(date: String?, label: String) -> some View {
        let isSelected = viewModel.selectedMapDay == date
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedMapDay = date
            }
        } label: {
            Text(label)
                .font(AppTheme.TextStyle.captionBold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
                .background(
                    isSelected
                        ? AnyShapeStyle(AppTheme.tripGradient)
                        : AnyShapeStyle(AppTheme.surfaceContainerLow)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func formattedDayLabel(_ dateString: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter()
        display.dateFormat = "EEE, MMM d"
        return fmt.date(from: dateString).map { display.string(from: $0) } ?? dateString
    }

    // MARK: - Error Phase

    private func errorPhase(_ message: String) -> some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Generation Failed")
                .font(.headline)
            Text(message)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.lg)
            Button("Try Again") {
                viewModel.phase = .configure
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - No Budget Phase

    private var noBudgetPhase: some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.onSurfaceVariant)
            Text("Budget Required")
                .font(.headline)
            Text("Set a trip budget before generating an AI itinerary. This helps the AI suggest activities within your spending plan.")
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.lg)
            Button("Set Budget") {
                dismiss()
                onGoToBudget()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func addToTrip() {
        let newActivities = viewModel.buildSelectedActivities()
        trip.activities.append(contentsOf: newActivities)
        dismiss()
    }
}

// MARK: - Map View

struct AIItineraryMapView: View {
    let activities: [AIActivity]

    private var cameraPosition: MapCameraPosition {
        let coords = activities.compactMap { a -> CLLocationCoordinate2D? in
            guard let lat = a.latitude, let lon = a.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return .automatic }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let centerLat = (lats.max()! + lats.min()!) / 2
        let centerLon = (lons.max()! + lons.min()!) / 2
        let spanLat = max((lats.max()! - lats.min()!) * 1.5, 0.02)
        let spanLon = max((lons.max()! - lons.min()!) * 1.5, 0.02)

        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        ))
    }

    private var polylineCoords: [CLLocationCoordinate2D] {
        activities.compactMap { a in
            guard let lat = a.latitude, let lon = a.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    var body: some View {
        Map(position: .constant(cameraPosition)) {
            if polylineCoords.count > 1 {
                MapPolyline(coordinates: polylineCoords)
                    .stroke(
                        AppTheme.secondary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                MapPolyline(coordinates: polylineCoords)
                    .stroke(
                        AppTheme.tripGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
            }
            ForEach(activities, id: \.id) { activity in
                if let lat = activity.latitude, let lon = activity.longitude {
                    Annotation(
                        activity.title,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        anchor: .bottom
                    ) {
                        Image("MapPinCashew")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 44)
                            .shadow(color: AppTheme.secondary.opacity(0.35), radius: 4, x: 0, y: 2)
                            .accessibilityLabel(activity.title)
                    }
                }
            }
        }
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        )
        .overlay {
            LinearGradient(
                colors: [
                    AppTheme.secondary.opacity(0.22),
                    .clear,
                    AppTheme.primary.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                Text("AI Route")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.black.opacity(0.38))
            )
            .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(activities.count) places")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.secondary.opacity(0.85))
                )
                .padding(12)
        }
    }
}

// MARK: - Activity Row

private struct AIActivityRow: View {
    let activity: AIActivity
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AppTheme.secondary : AppTheme.onSurfaceVariant)

                let category = ActivityCategory(rawValue: activity.category) ?? .activity
                Image(systemName: category.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.onSurface)

                    if let st = activity.startTime {
                        let timeLabel = activity.endTime.map { "\(st) – \($0)" } ?? st
                        Label(timeLabel, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }

                    if !activity.address.isEmpty {
                        Label(activity.address, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .lineLimit(1)
                    }

                    if let cost = activity.estimatedCost, cost > 0 {
                        Label("~\(String(format: "%.0f", cost)) est.", systemImage: "creditcard")
                            .font(.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }

                    if !activity.notes.isEmpty {
                        Text(activity.notes)
                            .font(.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .tripSoftSurface()
            .opacity(isSelected ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
