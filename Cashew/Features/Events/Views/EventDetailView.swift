import SwiftUI

struct EventDetailView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let eventId: UUID

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var error: String?
    @State private var showError = false
    @State private var shareURL: URL?
    @State private var isGeneratingShare = false
    @State private var showCollaborators = false

    private var event: Event? {
        container.eventService.event(by: eventId)
    }

    var body: some View {
        Group {
            if let event {
                eventContent(event)
            } else {
                ContentUnavailableView(
                    "Event Not Found",
                    systemImage: "star.slash",
                    description: Text("This event may have been deleted")
                )
            }
        }
        .navigationTitle(event?.title ?? "Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if event != nil {
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
                                isGeneratingShare ? "Generating…" : "Share Event",
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
            if let event {
                EventFormView(
                    viewModel: EventFormViewModel(
                        eventService: container.eventService,
                        event: event
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
            if let event {
                CollaboratorsView(resource: .event(event))
            }
        }
        .confirmationDialog(
            "Delete Event",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete this event? This action cannot be undone.")
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

    private func eventContent(_ event: Event) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Shared by banner
                if let name = event.ownerName {
                    sharedByBanner(name: name)
                }

                // Hero Header
                eventHeader(event)

                // Details Card
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Details", icon: "info.circle")

                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: event.category.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(event.category.color)
                                .frame(width: 28)
                            Text("Category")
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Spacer()
                            CategoryBadge(category: event.category, customName: event.customCategoryName, style: .prominent)
                        }

                        
                        HStack {
                            Image(systemName: event.priority.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(priorityColor(event.priority))
                                .frame(width: 28)
                            Text("Priority")
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Spacer()
                            Text(event.priority.displayName)
                                .fontWeight(.medium)
                                .foregroundStyle(priorityColor(event.priority))
                        }

                        if !event.location.isEmpty {
                                                        if let lat = event.locationLatitude, let lng = event.locationLongitude {
                                TappableLocationRow(
                                    icon: "mappin.circle.fill", iconColor: .red,
                                    label: "Location", value: event.location,
                                    latitude: lat, longitude: lng
                                )
                            } else {
                                detailRow(icon: "mappin.circle.fill", iconColor: .red, label: "Location", value: event.location)
                            }
                        }

                        if !event.address.isEmpty {
                                                        detailRow(icon: "map.fill", iconColor: .orange, label: "Address", value: event.address)
                        }
                    }
                    .padding()
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))

                // Date & Time Card
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Date & Time", icon: "calendar")

                    VStack(spacing: 12) {
                        if event.isAllDay {
                            detailRow(icon: "calendar.circle.fill", iconColor: .blue, label: "Date", value: event.date.formatted(date: .long, time: .omitted))

                            
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.orange)
                                    .frame(width: 28)
                                Text("All Day")
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                                Spacer()
                                Text("Yes")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                            }
                        } else {
                            detailRow(icon: "play.circle.fill", iconColor: .green, label: "Starts", value: event.date.formatted(date: .long, time: .shortened))

                            if let endDate = event.endDate {
                                
                                detailRow(icon: "stop.circle.fill", iconColor: .red, label: "Ends", value: endDate.formatted(date: .long, time: .shortened))

                                
                                detailRow(icon: "clock.fill", iconColor: .purple, label: "Duration", value: durationText(from: event.date, to: endDate))
                            }
                        }

                        // Recurrence
                        if let rule = event.recurrenceRule {
                            
                            HStack {
                                Image(systemName: "repeat")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                Text("Repeats")
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                                Spacer()
                                Text(rule.displayText)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding()
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))

                // Reminders Card
                if !event.reminders.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Reminders", icon: "bell.fill")

                        VStack(spacing: 12) {
                            ForEach(event.reminders) { reminder in
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.orange)
                                        .frame(width: 28)
                                    Text(reminder.interval.displayName)
                                        .foregroundStyle(AppTheme.onSurfaceVariant)
                                    Spacer()
                                    if reminder.isEnabled {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                }

                // Links & Cost Card
                let nonPhotoAttachments = event.attachments.filter { $0.type != .image }
                if event.url != nil || event.cost != nil || !nonPhotoAttachments.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Links & Cost", icon: "link")

                        VStack(spacing: 12) {
                            if let url = event.url {
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.blue)
                                        .frame(width: 28)
                                    Link(url.host ?? url.absoluteString, destination: url)
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(AppTheme.onSurfaceVariant)
                                }
                            }

                            if let cost = event.cost {
                                detailRow(icon: "creditcard.fill", iconColor: .green, label: "Cost", value: formatCost(cost, currency: event.currency))
                            }

                            ForEach(nonPhotoAttachments) { attachment in
                                
                                HStack {
                                    Image(systemName: attachment.type.icon)
                                        .font(.system(size: 20))
                                        .foregroundStyle(.purple)
                                        .frame(width: 28)
                                    Text(attachment.name)
                                        .font(.subheadline)
                                    Spacer()
                                    if let url = attachment.url {
                                        Link(destination: url) {
                                            Image(systemName: "arrow.up.right.square")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                }

                // Photos Card
                PhotosGridCard(attachments: event.attachments, accentColor: .purple)

                // Notes Card
                if !event.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Notes", icon: "note.text")

                        Text(event.notes)
                            .font(.body)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                }

                // Linked Tasks Card
                linkedTasksCard(eventId: event.id)

                // Info Card
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Info", icon: "clock.arrow.circlepath")

                    VStack(spacing: 12) {
                        detailRow(icon: "plus.circle.fill", iconColor: .gray, label: "Created", value: event.createdAt.formatted(date: .abbreviated, time: .shortened))

                        
                        detailRow(icon: "pencil.circle.fill", iconColor: .gray, label: "Updated", value: event.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .padding()
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            }
            .padding()
        }
        .background(AppTheme.background)
    }

    private func priorityColor(_ priority: EventPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .red
        }
    }

    private func formatCost(_ cost: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: cost as NSNumber) ?? "\(currency) \(cost)"
    }

    private func eventHeader(_ event: Event) -> some View {
        VStack(spacing: 16) {
            // Category icon
            Image(systemName: event.category.icon)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(event.category.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            // Title
            VStack(spacing: 4) {
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if !event.location.isEmpty {
                    if let lat = event.locationLatitude, let lng = event.locationLongitude {
                        Button {
                            MapLink.open(name: event.location, latitude: lat, longitude: lng)
                        } label: {
                            Label(event.location, systemImage: "location.fill")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    } else {
                        Label(event.location, systemImage: "location.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }
            }

            // Time indicator
            timeIndicatorView(for: event)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    @ViewBuilder
    private func timeIndicatorView(for event: Event) -> some View {
        let calendar = Calendar.current
        if calendar.isDateInToday(event.date) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Today")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.red.opacity(0.1))
            .clipShape(Capsule())
        } else if calendar.isDateInTomorrow(event.date) {
            Text("Tomorrow")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1))
                .clipShape(Capsule())
        } else {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: event.date)).day ?? 0
            if days > 0 {
                HStack(spacing: 4) {
                    Text("\(days)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text(days == 1 ? "day away" : "days away")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.1))
                .clipShape(Capsule())
            } else if days < 0 {
                Text("Past event")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(Capsule())
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.purple)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceContainerLow)
    }

    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            Text(label)
                .foregroundStyle(AppTheme.onSurfaceVariant)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Linked Tasks

    @ViewBuilder
    private func linkedTasksCard(eventId: UUID) -> some View {
        let linkedTasks = container.dayPlannerService.allTasks.filter { $0.eventId == eventId }

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
                                    .foregroundStyle(task.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)

                                Text(task.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
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
        let components = Calendar.current.dateComponents([.hour, .minute], from: start, to: end)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    private func generateShareLink() async {
        guard let event else { return }
        isGeneratingShare = true
        do {
            shareURL = try await container.shareService.createInviteLink(for: .event(event))
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        isGeneratingShare = false
    }

    private func sharedByBanner(name: String) -> some View {
        HStack(spacing: AppTheme.Space.sm) {
            Image(systemName: "person.fill.checkmark")
                .font(.caption)
                .foregroundStyle(.pink)
            Text("Shared by \(name)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.pink)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(Color.pink.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    private func deleteEvent() {
        isDeleting = true
        Task {
            do {
                try await container.eventService.deleteEvent(by: eventId)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                showError = true
            }
            isDeleting = false
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(eventId: UUID())
            .environment(AppContainer())
    }
}
