import SwiftUI
import MapKit

struct ActivityDetailView: View {

    @Environment(\.dismiss) private var dismiss

    let activity: Activity
    @Binding var trip: Trip
    var isReadOnly: Bool = false

    @State private var showEditForm = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private static let costFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    heroCard
                    if activity.latitude != nil && activity.longitude != nil {
                        locationCard
                    }
                    scheduleCard
                    bookingCard
                    if !activity.notes.isEmpty {
                        notesCard
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }
            .background(AppTheme.background)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isReadOnly {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showEditForm = true }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showEditForm) {
                ActivityFormView(trip: $trip, activity: activity, defaultDate: activity.date)
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            HStack(alignment: .top, spacing: AppTheme.Space.md) {
                Image(systemName: activity.category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.title)
                        .font(AppTheme.TextStyle.title)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        heroChip(icon: activity.category.icon, label: activity.category.displayName)
                        if activity.isBooked {
                            heroChip(icon: "checkmark.seal.fill", label: "Booked")
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                heroChip(icon: "calendar", label: activity.date.formatted(date: .abbreviated, time: .omitted))
                if let startTime = activity.startTime {
                    let timeLabel = activity.endTime.map {
                        "\(Self.timeFormatter.string(from: startTime)) – \(Self.timeFormatter.string(from: $0))"
                    } ?? Self.timeFormatter.string(from: startTime)
                    heroChip(icon: "clock.fill", label: timeLabel)
                }
                if let cost = activity.cost {
                    heroChip(icon: "creditcard", label: formatCost(cost))
                }
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

    // MARK: - Location Card

    private var locationCard: some View {
        sectionCard("Location", icon: "mappin") {
            VStack(spacing: 12) {
                if let lat = activity.latitude, let lon = activity.longitude {
                    Map(position: .constant(.region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                    )))) {
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
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .allowsHitTesting(false)

                    Button {
                        openInMaps()
                    } label: {
                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(AppTheme.TextStyle.bodyBold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.secondary)
                }

                if !activity.location.isEmpty {
                    detailLine(icon: "building.2", tint: .blue, title: "Place", value: activity.location)
                }
                if !activity.address.isEmpty {
                    detailLine(icon: "mappin.and.ellipse", tint: .orange, title: "Address", value: activity.address)
                }
            }
        }
    }

    // MARK: - Schedule Card

    private var scheduleCard: some View {
        sectionCard("Schedule", icon: "clock.fill") {
            VStack(spacing: 12) {
                detailLine(
                    icon: "calendar",
                    tint: .blue,
                    title: "Date",
                    value: activity.date.formatted(date: .long, time: .omitted)
                )

                if let startTime = activity.startTime {
                    detailLine(
                        icon: "clock.fill",
                        tint: .purple,
                        title: "Start",
                        value: Self.timeFormatter.string(from: startTime)
                    )
                    if let endTime = activity.endTime {
                        detailLine(
                            icon: "clock.badge.checkmark",
                            tint: .purple,
                            title: "End",
                            value: Self.timeFormatter.string(from: endTime)
                        )
                    }
                } else {
                    detailLine(icon: "clock.fill", tint: .gray, title: "Time", value: "Flexible / No specific time")
                }
            }
        }
    }

    // MARK: - Booking Card

    private var bookingCard: some View {
        sectionCard("Booking", icon: "checkmark.seal") {
            VStack(spacing: 12) {
                if let cost = activity.cost {
                    detailLine(icon: "creditcard", tint: .green, title: "Cost", value: formatCost(cost))
                }

                detailLine(
                    icon: activity.isBooked ? "checkmark.seal.fill" : "circle",
                    tint: activity.isBooked ? .green : .gray,
                    title: "Status",
                    value: activity.isBooked ? "Booked" : "Not booked"
                )

                if activity.isBooked && !activity.confirmationNumber.isEmpty {
                    detailLine(
                        icon: "number",
                        tint: .blue,
                        title: "Confirmation",
                        value: activity.confirmationNumber
                    )
                }

                if let link = activity.link {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 24)

                        Text("Link")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurfaceVariant)

                        Spacer(minLength: 10)

                        Link(destination: link) {
                            Text("Open")
                                .font(AppTheme.TextStyle.bodyBold)
                                .foregroundStyle(AppTheme.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        sectionCard("Notes", icon: "note.text") {
            Text(activity.notes)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Card Helpers

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

    // MARK: - Helpers

    private func formatCost(_ cost: Decimal) -> String {
        Self.costFormatter.currencyCode = activity.currency
        return Self.costFormatter.string(from: cost as NSNumber) ?? "\(activity.currency) \(cost)"
    }

    private func openInMaps() {
        guard let lat = activity.latitude, let lon = activity.longitude else { return }
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = activity.location.isEmpty ? activity.title : activity.location
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

#Preview {
    ActivityDetailView(
        activity: Activity(
            title: "Eiffel Tower Visit",
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(7200),
            location: "Eiffel Tower",
            address: "Champ de Mars, 5 Av. Anatole France, 75007 Paris",
            notes: "Book tickets online in advance to skip the queue. The summit offers the best views but can be crowded.",
            category: .tour,
            cost: 26.50,
            currency: "EUR",
            isBooked: true,
            confirmationNumber: "ET-2026-4815",
            latitude: 48.8584,
            longitude: 2.2945
        ),
        trip: .constant(Trip(
            name: "Paris Trip",
            destination: "Paris, France",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 5)
        ))
    )
}
