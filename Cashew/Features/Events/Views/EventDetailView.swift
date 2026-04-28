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
    @State private var revealContent = false
    @State private var hasCollaborators = false

    private var event: Event? {
        container.eventService.event(by: eventId)
    }

    private var isOwner: Bool {
        guard let event else { return false }
        guard let ownerId = event.ownerId else { return true }
        return ownerId == container.authService.currentUser?.id
    }

    private var canEdit: Bool {
        event != nil
    }

    private func shouldShowSharedByBanner(for event: Event) -> Bool {
        guard let ownerName = event.ownerName, !ownerName.isEmpty else { return false }
        guard let ownerId = event.ownerId, let currentUserId = container.authService.currentUser?.id else {
            return true
        }
        return ownerId != currentUserId
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
                let eventTitle = event?.title ?? "an event"
                ShareSheet(items: ["Join me for \(eventTitle) in Cashew — plan together in real time!", url])
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
        .task(id: eventId) {
            guard isOwner, let event else { return }
            let collaborators = (try? await container.shareService.fetchCollaborators(for: .event(event))) ?? []
            hasCollaborators = !collaborators.isEmpty
        }
    }

    // MARK: - Content

    private func eventContent(_ event: Event) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.md) {
                if isOwner && hasCollaborators {
                    stagedCard(0) {
                        sharingActiveOwnerBanner
                    }
                } else if shouldShowSharedByBanner(for: event), let name = event.ownerName {
                    stagedCard(0) {
                        sharedByBanner(name: name)
                    }
                }

                stagedCard(1) {
                    eventHero(event)
                }

                stagedCard(2) {
                    snapshotCard(event)
                }

                stagedCard(3) {
                    coreDetailsCard(event)
                }

                if !event.reminders.isEmpty {
                    stagedCard(4) {
                        remindersCard(event)
                    }
                }

                if shouldShowResources(event) {
                    stagedCard(5) {
                        resourcesCard(event)
                    }
                }

                stagedCard(6) {
                    PhotosGridCard(attachments: event.attachments, accentColor: AppTheme.tertiary)
                }

                if !event.notes.isEmpty {
                    stagedCard(7) {
                        notesCard(event)
                    }
                }

                stagedCard(8) {
                    linkedTasksCard(eventId: event.id)
                }

                stagedCard(9) {
                    metaCard(event)
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
    }

    // MARK: - Hero

    private func eventHero(_ event: Event) -> some View {
        let status = temporalStatus(for: event)

        return VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            HStack(alignment: .top, spacing: AppTheme.Space.md) {
                Image(systemName: event.category.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(event.category.color.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(AppTheme.TextStyle.title)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        heroChip(icon: event.category.icon, label: event.categoryDisplayName)
                        heroChip(icon: event.priority.icon, label: event.priority.displayName)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: status.icon)
                    Text(status.text)
                }
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(status.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(AppTheme.surfaceContainerLowest.opacity(0.95))
                .clipShape(Capsule())
            }

            if !event.location.isEmpty {
                if let lat = event.locationLatitude, let lng = event.locationLongitude {
                    Button {
                        MapLink.open(name: event.location, latitude: lat, longitude: lng)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(event.location)
                                .lineLimit(1)
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.16))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    heroChip(icon: "mappin.and.ellipse", label: event.location)
                }
            }

            HStack(spacing: 8) {
                heroChip(icon: "calendar", label: event.date.formatted(date: .abbreviated, time: .omitted))
                heroChip(icon: event.isAllDay ? "sun.max.fill" : "clock.fill", label: timeSummary(for: event))
                if event.recurrenceRule != nil {
                    heroChip(icon: "repeat", label: "Repeats")
                }
            }
        }
        .padding(AppTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.eventGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: AppTheme.tertiary.opacity(0.20), radius: 16, x: 0, y: 8)
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

    // MARK: - Cards

    private func snapshotCard(_ event: Event) -> some View {
        sectionCard("Snapshot", icon: "sparkles") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Space.sm) {
                snapshotTile(
                    icon: "calendar.circle.fill",
                    title: "Date",
                    value: event.date.formatted(date: .abbreviated, time: .omitted),
                    tint: .blue
                )
                snapshotTile(
                    icon: event.isAllDay ? "sun.max.fill" : "clock.fill",
                    title: "Time",
                    value: timeSummary(for: event),
                    tint: event.isAllDay ? .orange : .purple
                )
                snapshotTile(
                    icon: "repeat",
                    title: "Recurrence",
                    value: event.recurrenceRule?.displayText ?? "Does not repeat",
                    tint: AppTheme.tertiary
                )
                snapshotTile(
                    icon: "hourglass",
                    title: "Duration",
                    value: event.formattedDuration ?? "Not set",
                    tint: .green
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

    private func coreDetailsCard(_ event: Event) -> some View {
        sectionCard("Core Details", icon: "info.circle") {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: event.category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(event.category.color)
                        .frame(width: 24)
                    Text("Category")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    Spacer()
                    CategoryBadge(category: event.category, customName: event.customCategoryName, style: .prominent)
                }

                detailLine(
                    icon: event.priority.icon,
                    tint: priorityColor(event.priority),
                    title: "Priority",
                    value: event.priority.displayName
                )

                if !event.location.isEmpty {
                    if let lat = event.locationLatitude, let lng = event.locationLongitude {
                        Button {
                            MapLink.open(name: event.location, latitude: lat, longitude: lng)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.negative)
                                    .frame(width: 24)

                                Text("Location")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)

                                Spacer(minLength: 10)

                                Text(event.location)
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
                        detailLine(icon: "mappin.circle.fill", tint: AppTheme.negative, title: "Location", value: event.location)
                    }
                }

                if !event.address.isEmpty {
                    detailLine(icon: "map.fill", tint: AppTheme.warning, title: "Address", value: event.address)
                }

                if let tripId = event.tripId, let tripName = container.tripService.trip(by: tripId)?.name {
                    detailLine(icon: "airplane", tint: AppTheme.secondary, title: "Trip", value: tripName)
                }
            }
        }
    }

    private func remindersCard(_ event: Event) -> some View {
        sectionCard("Reminders", icon: "bell.fill") {
            VStack(spacing: AppTheme.Space.sm) {
                ForEach(event.reminders) { reminder in
                    HStack(spacing: 10) {
                        Image(systemName: reminder.isEnabled ? "bell.badge.fill" : "bell.slash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(reminder.isEnabled ? .orange : AppTheme.onSurfaceVariant)
                            .frame(width: 24)

                        Text(reminder.interval.displayName)
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)

                        Spacer()

                        Image(systemName: reminder.isEnabled ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(reminder.isEnabled ? .green : AppTheme.onSurfaceVariant)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func resourcesCard(_ event: Event) -> some View {
        let nonPhotoAttachments = event.attachments.filter { $0.type != .image }

        return sectionCard("Resources", icon: "link") {
            VStack(spacing: 12) {
                if let url = event.url {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 24)

                        Text("Website")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurfaceVariant)

                        Spacer(minLength: 10)

                        Link(url.host ?? url.absoluteString, destination: url)
                            .font(AppTheme.TextStyle.bodyBold)
                            .lineLimit(1)

                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }

                if let cost = event.cost {
                    detailLine(
                        icon: "creditcard.fill",
                        tint: .green,
                        title: "Cost",
                        value: formatCost(cost, currency: event.currency)
                    )
                }

                ForEach(nonPhotoAttachments) { attachment in
                    HStack(spacing: 10) {
                        Image(systemName: attachment.type.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.purple)
                            .frame(width: 24)

                        Text("Attachment")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurfaceVariant)

                        Spacer(minLength: 10)

                        Text(attachment.name)
                            .font(AppTheme.TextStyle.bodyBold)
                            .lineLimit(1)

                        if let url = attachment.url {
                            Link(destination: url) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
    }

    private func notesCard(_ event: Event) -> some View {
        sectionCard("Notes", icon: "note.text") {
            Text(event.notes)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(AppTheme.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func metaCard(_ event: Event) -> some View {
        sectionCard("Info", icon: "clock.arrow.circlepath") {
            VStack(spacing: 12) {
                detailLine(
                    icon: "plus.circle.fill",
                    tint: AppTheme.onSurfaceVariant,
                    title: "Created",
                    value: event.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
                detailLine(
                    icon: "pencil.circle.fill",
                    tint: AppTheme.onSurfaceVariant,
                    title: "Updated",
                    value: event.updatedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    // MARK: - Linked Tasks

    @ViewBuilder
    private func linkedTasksCard(eventId: UUID) -> some View {
        let linkedTasks = container.dayPlannerService.allTasks.filter { $0.eventId == eventId }

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

                            HStack(spacing: 4) {
                                Image(systemName: task.category.icon)
                                Text(task.categoryDisplayName)
                            }
                            .font(AppTheme.TextStyle.caption)
                            .foregroundStyle(task.category.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(task.category.color.opacity(0.12))
                            .clipShape(Capsule())
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

    // MARK: - Reusable Building Blocks

    private func sectionCard<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            SectionHeader(icon: icon, title: title, gradient: AppTheme.eventGradient)
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

    // MARK: - Helpers

    private func shouldShowResources(_ event: Event) -> Bool {
        let nonPhotoAttachments = event.attachments.filter { $0.type != .image }
        return event.url != nil || event.cost != nil || !nonPhotoAttachments.isEmpty
    }

    private func temporalStatus(for event: Event) -> (text: String, icon: String, color: Color) {
        let calendar = Calendar.current

        if calendar.isDateInToday(event.date) {
            return ("Today", "circle.fill", .red)
        }
        if calendar.isDateInTomorrow(event.date) {
            return ("Tomorrow", "sunrise.fill", .orange)
        }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: event.date)
        ).day ?? 0

        if days > 0 {
            return ("In \(days)d", "calendar.badge.clock", .blue)
        } else if days < 0 {
            return ("Past", "clock.arrow.trianglehead.counterclockwise.rotate.90", AppTheme.onSurfaceVariant)
        }

        return ("Upcoming", "calendar", .blue)
    }

    private func timeSummary(for event: Event) -> String {
        if event.isAllDay {
            return "All Day"
        }

        if let endDate = event.endDate {
            return "\(event.date.formatted(date: .omitted, time: .shortened)) - \(endDate.formatted(date: .omitted, time: .shortened))"
        }

        return event.date.formatted(date: .omitted, time: .shortened)
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

    private func generateShareLink() async {
        guard let event else { return }
        guard container.dataSyncService.isEnabled else {
            error = "Enable CashewCloud in Settings to share events."
            showError = true
            return
        }
        isGeneratingShare = true
        do {
            shareURL = try await container.shareService.createInviteLink(for: .event(event))
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        isGeneratingShare = false
    }

    private var sharingActiveOwnerBanner: some View {
        HStack(spacing: AppTheme.Space.sm) {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.primary)
            Text("You're sharing this event")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.primary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.primary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sharedByBanner(name: String) -> some View {
        HStack(spacing: AppTheme.Space.sm) {
            Image(systemName: "person.fill.checkmark")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiary)
            Text("Shared by \(name)")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.tertiary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.tertiary.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
