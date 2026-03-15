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

    private var trip: Trip? {
        container.tripService.trip(by: tripId)
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
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            Task { await generateShareLink() }
                        } label: {
                            Label(
                                isGeneratingShare ? "Generating…" : "Share Trip",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .disabled(isGeneratingShare)

                        Button {
                            showCollaborators = true
                        } label: {
                            Label("Manage Access", systemImage: "person.2")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
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
                ShareSheet(items: [url])
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
    }

    // MARK: - Content

    private func tripContent(_ trip: Trip) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Shared by banner
                if let name = trip.ownerName {
                    sharedByBanner(name: name, color: .orange)
                }

                // Hero Header
                tripHeader(trip)

                // Quick Actions Grid
                quickActionsGrid(trip)

                // Details Card
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Details", icon: "info.circle")

                    VStack(spacing: 12) {
                        if let lat = trip.destinationLatitude, let lng = trip.destinationLongitude {
                            TappableLocationRow(
                                icon: "mappin.circle.fill", iconColor: .red,
                                label: "Destination", value: trip.destination,
                                latitude: lat, longitude: lng
                            )
                        } else {
                            detailRow(icon: "mappin.circle.fill", iconColor: .red, label: "Destination", value: trip.destination)
                        }

                        Divider().padding(.leading, 44)

                        HStack {
                            Image(systemName: "flag.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            Text("Status")
                                .foregroundStyle(.secondary)
                            Spacer()
                            StatusBadge(status: trip.computedStatus, style: .prominent)
                        }
                    }
                    .padding()
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))

                // Dates Card
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Dates", icon: "calendar")

                    VStack(spacing: 12) {
                        detailRow(icon: "airplane.departure", iconColor: .green, label: "Start", value: trip.startDate.formatted(date: .long, time: .omitted))

                        Divider().padding(.leading, 44)

                        detailRow(icon: "airplane.arrival", iconColor: .orange, label: "End", value: trip.endDate.formatted(date: .long, time: .omitted))

                        Divider().padding(.leading, 44)

                        detailRow(icon: "clock.fill", iconColor: .purple, label: "Duration", value: durationText(from: trip.startDate, to: trip.endDate))
                    }
                    .padding()
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))

                // Photos Card
                PhotosGridCard(attachments: trip.attachments, accentColor: .blue)

                // Notes Card
                if !trip.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Notes", icon: "note.text")

                        Text(trip.notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                }

                // Linked Tasks Card
                linkedTasksCard(tripId: trip.id)

                // Info Card
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Info", icon: "clock.arrow.circlepath")

                    VStack(spacing: 12) {
                        detailRow(icon: "plus.circle.fill", iconColor: .gray, label: "Created", value: trip.createdAt.formatted(date: .abbreviated, time: .shortened))

                        Divider().padding(.leading, 44)

                        detailRow(icon: "pencil.circle.fill", iconColor: .gray, label: "Updated", value: trip.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .padding()
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Quick Actions Grid

    private func quickActionsGrid(_ trip: Trip) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // Budget
            NavigationLink(value: TripSection.budget) {
                QuickActionCard(
                    icon: "creditcard.fill",
                    title: "Budget",
                    subtitle: budgetSubtitle(trip),
                    progress: trip.budgetProgress,
                    color: .green
                )
            }
            .buttonStyle(.plain)

            // Itinerary
            NavigationLink(value: TripSection.itinerary) {
                QuickActionCard(
                    icon: "calendar.day.timeline.left",
                    title: "Itinerary",
                    subtitle: "\(trip.activities.count) activities",
                    progress: nil,
                    color: .blue
                )
            }
            .buttonStyle(.plain)

            // Packing
            NavigationLink(value: TripSection.packing) {
                QuickActionCard(
                    icon: "bag.fill",
                    title: "Packing",
                    subtitle: packingSubtitle(trip),
                    progress: trip.packingItems.isEmpty ? nil : trip.packingProgress,
                    color: .orange
                )
            }
            .buttonStyle(.plain)

            // Checklist
            NavigationLink(value: TripSection.checklist) {
                QuickActionCard(
                    icon: "checklist",
                    title: "Checklist",
                    subtitle: checklistSubtitle(trip),
                    progress: trip.checklistItems.isEmpty ? nil : trip.checklistProgress,
                    color: .purple
                )
            }
            .buttonStyle(.plain)
        }
        .navigationDestination(for: TripSection.self) { section in
            tripSectionView(section, trip: trip)
        }
    }

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

    @ViewBuilder
    private func tripSectionView(_ section: TripSection, trip: Trip) -> some View {
        let tripBinding = Binding<Trip>(
            get: { container.tripService.trip(by: tripId) ?? trip },
            set: { newTrip in
                Task {
                    try? await container.tripService.updateTrip(newTrip)
                }
            }
        )

        switch section {
        case .budget:
            TripBudgetView(trip: tripBinding)
        case .itinerary:
            TripItineraryView(trip: tripBinding)
        case .packing:
            TripPackingView(trip: tripBinding)
        case .checklist:
            TripChecklistView(trip: tripBinding)
        }
    }

    private func sharedByBanner(name: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Space.sm) {
            Image(systemName: "person.fill.checkmark")
                .font(.caption)
                .foregroundStyle(color)
            Text("Shared by \(name)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    private func tripHeader(_ trip: Trip) -> some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.tripGradient)

            // Title and destination
            VStack(spacing: 4) {
                Text(trip.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let lat = trip.destinationLatitude, let lng = trip.destinationLongitude {
                    Button {
                        MapLink.open(name: trip.destination, latitude: lat, longitude: lng)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(trip.destination)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Days indicator
            if trip.computedStatus == .upcoming {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: trip.startDate).day ?? 0
                if days > 0 {
                    HStack(spacing: 4) {
                        Text("\(days)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("days until departure")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
            } else if trip.computedStatus == .active {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Currently on this trip")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.green.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
    }

    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Linked Tasks

    @ViewBuilder
    private func linkedTasksCard(tripId: UUID) -> some View {
        let linkedTasks = container.dayPlannerService.allTasks.filter { $0.tripId == tripId }

        if !linkedTasks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Linked Tasks", icon: "checklist")

                VStack(spacing: 0) {
                    ForEach(linkedTasks) { task in
                        HStack(spacing: 12) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(task.isCompleted ? .green : task.category.color)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .strikethrough(task.isCompleted)
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                                Text(task.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                        if task.id != linkedTasks.last?.id {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        }
    }

    // MARK: - Helpers

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

// MARK: - Trip Section

enum TripSection: Hashable {
    case budget
    case itinerary
    case packing
    case checklist
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
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.gradient)
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }
}

#Preview {
    NavigationStack {
        TripDetailView(tripId: UUID())
            .environment(AppContainer())
    }
}
