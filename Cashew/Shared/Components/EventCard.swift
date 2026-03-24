import SwiftUI

struct EventCard: View {
    let event: Event
    var style: CardStyle = .full

    enum CardStyle {
        case full
        case compact
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        switch style {
        case .full:
            fullCard
        case .compact:
            compactCard
        }
    }

    // MARK: - Full Card

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.cardInternalSpacing) {
            // Header with icon and category
            HStack(alignment: .top) {
                // Category icon
                Image(systemName: event.category.icon)
                    .iconBackground(event.category.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(AppTheme.TextStyle.sectionTitle)
                        .foregroundStyle(AppTheme.onSurface)
                        .lineLimit(2)

                    if !event.location.isEmpty {
                        Label(event.location, systemImage: "location.fill")
                            .font(AppTheme.TextStyle.secondary)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                }

                Spacer()

                CategoryBadge(category: event.category, customName: event.customCategoryName)
            }

            // Date and time info (whitespace separation, no divider)
            HStack(spacing: 16) {
                // Date
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date")
                        .font(AppTheme.TextStyle.micro)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .textCase(.uppercase)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(AppTheme.TextStyle.micro)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        Text(Self.dateFormatter.string(from: event.date))
                            .font(AppTheme.TextStyle.captionBold)
                    }
                }

                // Time
                if !event.isAllDay {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time")
                            .font(AppTheme.TextStyle.micro)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .textCase(.uppercase)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(AppTheme.TextStyle.micro)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Text(timeDisplay)
                                .font(AppTheme.TextStyle.captionBold)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(AppTheme.TextStyle.micro)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .textCase(.uppercase)

                        Text("All Day")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(AppTheme.primary)
                    }
                }

                Spacer()

                // Relative time indicator
                relativeTimeView
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Compact Card

    private var compactCard: some View {
        HStack(spacing: 12) {
            // Tinted category icon circle
            ZStack {
                Circle()
                    .fill(event.category.color.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: event.category.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(event.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Title
                Text(event.title)
                    .font(AppTheme.TextStyle.bodyBold)
                    .foregroundStyle(AppTheme.onSurface)
                    .lineLimit(1)

                // Line 2: Time · Category
                Text(compactSubtitle)
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .lineLimit(1)

                // Line 3: Location (optional)
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "location")
                        .font(AppTheme.TextStyle.micro)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(compactAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var compactSubtitle: String {
        var parts: [String] = []
        if event.isAllDay {
            parts.append("All Day")
        } else {
            let start = Self.timeFormatter.string(from: event.date)
            if let end = event.endDate {
                parts.append("\(start) – \(Self.timeFormatter.string(from: end))")
            } else {
                parts.append(start)
            }
        }
        parts.append(event.category.displayName)
        return parts.joined(separator: " · ")
    }

    private var compactAccessibilityLabel: String {
        var parts = [event.title]
        if event.isAllDay {
            parts.append("all day")
        } else {
            parts.append(Self.timeFormatter.string(from: event.date))
            if let end = event.endDate {
                parts.append("to \(Self.timeFormatter.string(from: end))")
            }
        }
        parts.append(event.category.displayName)
        if !event.location.isEmpty { parts.append("at \(event.location)") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Helper Views

    private var timeDisplay: String {
        let start = Self.timeFormatter.string(from: event.date)
        if let end = event.endDate {
            let endTime = Self.timeFormatter.string(from: end)
            return "\(start) - \(endTime)"
        }
        return start
    }

    private var relativeTimeView: some View {
        Group {
            let calendar = Calendar.current
            if calendar.isDateInToday(event.date) {
                todayBadge
            } else if calendar.isDateInTomorrow(event.date) {
                tomorrowBadge
            } else {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: event.date)).day ?? 0
                if days > 0 && days <= 7 {
                    upcomingBadge(days: days)
                } else if days < 0 {
                    pastBadge
                }
            }
        }
    }

    private var pastBadge: some View {
        Text("Past")
            .font(AppTheme.TextStyle.captionBold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.surfaceContainerHigh)
            .foregroundStyle(AppTheme.onSurfaceVariant)
            .clipShape(Capsule())
    }

    private var todayBadge: some View {
        Text("Today")
            .font(AppTheme.TextStyle.captionBold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.tertiary.opacity(0.15))
            .foregroundStyle(AppTheme.tertiary)
            .clipShape(Capsule())
    }

    private var tomorrowBadge: some View {
        Text("Tomorrow")
            .font(AppTheme.TextStyle.captionBold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.secondary.opacity(0.15))
            .foregroundStyle(AppTheme.secondary)
            .clipShape(Capsule())
    }

    private func upcomingBadge(days: Int) -> some View {
        Text("In \(days)d")
            .font(AppTheme.TextStyle.captionBold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.primary.opacity(0.15))
            .foregroundStyle(AppTheme.primary)
            .clipShape(Capsule())
    }
}

#Preview("Full Card") {
    ScrollView {
        VStack(spacing: 16) {
            EventCard(event: Event(
                title: "Team Standup Meeting",
                date: Date(),
                endDate: Date().addingTimeInterval(3600),
                location: "Conference Room A",
                category: .meeting
            ))

            EventCard(event: Event(
                title: "Birthday Party",
                date: Date().addingTimeInterval(86400),
                location: "Central Park",
                category: .social,
                isAllDay: true
            ))

            EventCard(event: Event(
                title: "Flight to Tokyo",
                date: Date().addingTimeInterval(86400 * 5),
                location: "JFK Airport",
                category: .travel
            ))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Compact Card") {
    ScrollView {
        VStack(spacing: 12) {
            EventCard(event: Event(
                title: "Team Standup Meeting",
                date: Date(),
                location: "Conference Room A",
                category: .meeting
            ), style: .compact)

            EventCard(event: Event(
                title: "Birthday Party",
                date: Date().addingTimeInterval(86400),
                location: "Central Park",
                category: .social,
                isAllDay: true
            ), style: .compact)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
