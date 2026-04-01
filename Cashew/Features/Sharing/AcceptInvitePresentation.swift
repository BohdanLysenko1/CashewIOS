import Foundation

enum AcceptInvitePresentation {

    static func iconName(for resource: SharedResource) -> String {
        switch resource {
        case .trip:  return "airplane.circle.fill"
        case .event: return "star.circle.fill"
        }
    }

    static func title(for resource: SharedResource) -> String {
        switch resource {
        case .trip(let trip):  return trip.name
        case .event(let event): return event.title
        }
    }

    static func subtitle(
        for resource: SharedResource,
        tripFormatter: DateFormatter = tripDateFormatter,
        eventFormatter: DateFormatter = eventDateFormatter
    ) -> String {
        switch resource {
        case .trip(let trip):
            return "\(tripFormatter.string(from: trip.startDate)) – \(tripFormatter.string(from: trip.endDate))"
        case .event(let event):
            return eventFormatter.string(from: event.date)
        }
    }

    static func sharedBy(for resource: SharedResource) -> String? {
        switch resource {
        case .trip(let trip):  return trip.ownerName
        case .event(let event): return event.ownerName
        }
    }

    static func resourceTypeName(for resource: SharedResource) -> String {
        switch resource {
        case .trip:  return "Trip"
        case .event: return "Event"
        }
    }

    private static let tripDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
