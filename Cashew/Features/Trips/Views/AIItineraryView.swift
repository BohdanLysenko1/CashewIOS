import SwiftUI
import MapKit

// MARK: - Main View

struct AIItineraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip
    @State private var viewModel: AIItineraryViewModel
    @State private var selectedAIActivity: AIActivity?
    let onGoToBudget: () -> Void

    init(
        trip: Binding<Trip>,
        onGoToBudget: @escaping () -> Void,
        viewModel: AIItineraryViewModel? = nil
    ) {
        _trip = trip
        _viewModel = State(initialValue: viewModel ?? AIItineraryViewModel(trip: trip.wrappedValue))
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
        .sheet(item: $selectedAIActivity) { aiActivity in
            ActivityDetailView(
                activity: aiActivity.toActivity(tripStartDate: viewModel.trip.startDate, tripCurrency: viewModel.trip.currency),
                trip: $trip,
                isReadOnly: true
            )
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
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

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
                        ForEach(viewModel.availableInterests) { interest in
                            let isSelected = viewModel.selectedInterests.contains(interest.id)

                            Button {
                                viewModel.toggleInterest(interest.id)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: interest.icon)
                                        .font(.system(size: AppTheme.sectionIconSize + 4))
                                    Text(interest.displayName)
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
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                        }
                    }
                }

                // Travel Style (vibe + pace)
                CreationSectionCard(title: "Travel Style", icon: "sparkles") {
                    VStack(alignment: .leading, spacing: AppTheme.Space.md) {
                        VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
                            Text("Vibe")
                                .font(AppTheme.TextStyle.captionBold)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Space.sm) {
                                    ForEach(TripVibe.allCases) { vibe in
                                        vibePill(vibe: vibe)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
                            Text("Pace")
                                .font(AppTheme.TextStyle.captionBold)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            HStack(spacing: AppTheme.Space.sm) {
                                ForEach(TripPace.allCases) { pace in
                                    pacePill(pace: pace)
                                }
                            }
                        }
                    }
                }

                // Notes for Gemini
                CreationSectionCard(title: "Notes for Gemini", icon: "text.bubble") {
                    VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
                        ZStack(alignment: .topLeading) {
                            if viewModel.userNote.isEmpty {
                                Text("e.g. vegetarian, traveling with a toddler, want a sunset hike")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.6))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $viewModel.userNote)
                                .font(AppTheme.TextStyle.body)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }
                        .background(AppTheme.surfaceContainer)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                        HStack {
                            Spacer()
                            Text("\(viewModel.userNote.count)/\(AIItineraryViewModel.userNoteCharLimit)")
                                .font(AppTheme.TextStyle.caption)
                                .foregroundStyle(
                                    viewModel.userNote.count > AIItineraryViewModel.userNoteCharLimit
                                        ? AppTheme.negative
                                        : AppTheme.onSurfaceVariant
                                )
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
            AIItineraryMapView(activities: viewModel.visibleMapActivities) { activity in
                selectedAIActivity = activity
            }
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
                                if viewModel.regeneratingDay == group.date {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(AppTheme.secondary)
                                        Text("Regenerating...")
                                            .font(AppTheme.TextStyle.caption)
                                            .foregroundStyle(AppTheme.onSurfaceVariant)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppTheme.Space.lg)
                                } else {
                                    ForEach(group.items) { activity in
                                        AIActivityRow(
                                            activity: activity,
                                            isSelected: viewModel.selectedIDs.contains(activity.id),
                                            onToggle: { viewModel.toggleActivity(activity) },
                                            onTap: { selectedAIActivity = activity }
                                        )
                                    }

                                    Button {
                                        Task { await viewModel.regenerateDay(group.date) }
                                    } label: {
                                        Label("Regenerate this day", systemImage: "arrow.trianglehead.2.clockwise")
                                            .font(AppTheme.TextStyle.caption)
                                            .foregroundStyle(AppTheme.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.top, 4)
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

    private func vibePill(vibe: TripVibe) -> some View {
        let isSelected = viewModel.selectedVibe == vibe
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedVibe = isSelected ? nil : vibe
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: vibe.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(vibe.displayName)
                    .font(AppTheme.TextStyle.captionBold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

    private func pacePill(pace: TripPace) -> some View {
        let isSelected = viewModel.selectedPace == pace
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedPace = pace
            }
        } label: {
            VStack(spacing: 2) {
                Text(pace.displayName)
                    .font(AppTheme.TextStyle.captionBold)
                Text(pace.subtitle)
                    .font(AppTheme.TextStyle.caption)
                    .opacity(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
            .background(
                isSelected
                    ? AnyShapeStyle(AppTheme.tripGradient)
                    : AnyShapeStyle(AppTheme.surfaceContainerLow)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func dayFilterPill(date: String?, label: String) -> some View {
        let isSelected = viewModel.selectedMapDay == date
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
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
        DateFormatting.isoDate.date(from: dateString)
            .map { DateFormatting.shortDayMonth.string(from: $0) } ?? dateString
    }

    // MARK: - Error Phase

    private func errorPhase(_ message: String) -> some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.negative)
            Text("Generation Failed")
                .font(AppTheme.TextStyle.sectionTitle)
            Text(message)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.lg)
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
                .font(AppTheme.TextStyle.sectionTitle)
            Text("Set a trip budget before generating an AI itinerary. This helps the AI suggest activities within your spending plan.")
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.lg)
            Button {
                dismiss()
                onGoToBudget()
            } label: {
                Text("Set Budget")
                    .primaryActionButton(gradient: AppTheme.tripGradient)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.Space.xl)
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
    var onPinTapped: ((AIActivity) -> Void)?

    @State private var cameraPos: MapCameraPosition = .automatic

    private var computedPosition: MapCameraPosition {
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
        Map(position: $cameraPos) {
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
            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                if let lat = activity.latitude, let lon = activity.longitude {
                    Annotation(
                        activity.title,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        anchor: .bottom
                    ) {
                        Button {
                            onPinTapped?(activity)
                        } label: {
                            NumberedMapPin(index: index + 1)
                        }
                        .buttonStyle(.plain)
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
        .onAppear { cameraPos = computedPosition }
        .onChange(of: activities) { _, _ in cameraPos = computedPosition }
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
                    .fill(AppTheme.scrim)
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
    let onTap: () -> Void

    private var category: ActivityCategory {
        ActivityCategory(rawValue: activity.category) ?? .activity
    }

    private var formattedTime: String? {
        guard let st = activity.startTime else { return nil }
        let start = Self.formatTime(st)
        if let et = activity.endTime {
            return "\(start) – \(Self.formatTime(et))"
        }
        return start
    }

    private static func formatTime(_ raw: String) -> String {
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return raw }
        let hour = parts[0]
        let minute = parts[1]
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return minute == 0
            ? "\(displayHour) \(period)"
            : "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar
            RoundedRectangle(cornerRadius: AppTheme.progressBarCornerRadius)
                .fill(category.color.gradient)
                .frame(width: 3)
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius))

                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.title)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)

                    if let time = formattedTime {
                        Label(time, systemImage: "clock")
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

                VStack(spacing: 8) {
                    Button(action: onToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? AppTheme.secondary : AppTheme.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.4))
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 14)
        }
        .tripSoftSurface()
        .opacity(isSelected ? 1.0 : 0.5)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Numbered Map Pin

struct NumberedMapPin: View {
    let index: Int

    var body: some View {
        ZStack {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.secondary)
                .shadow(color: AppTheme.secondary.opacity(0.35), radius: 4, x: 0, y: 2)

            Text("\(index)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: -1)
        }
    }
}
