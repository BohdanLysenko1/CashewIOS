import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case dashboard
    case events
    case calendar
    case trips
    case settings
    case complete

    var id: Int { rawValue }

    // MARK: - Content

    var title: String {
        switch self {
        case .welcome:   return "Welcome to Cashew"
        case .dashboard: return "Your Day at a Glance"
        case .events:    return "Track Every Moment"
        case .calendar:  return "The Big Picture"
        case .trips:     return "Plan Your Adventures"
        case .settings:  return "Make It Yours"
        case .complete:  return "You're All Set!"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "Plan your day, track your events, and organize every trip."
        case .dashboard:
            return "See upcoming trips, events, and tasks at a glance. Tap Plan My Day to organize your schedule and earn XP as you complete tasks."
        case .events:
            return "Track events with priorities, reminders, and costs. Add recurring schedules and link events to your trips."
        case .calendar:
            return "Your trips, events, and tasks on one calendar. Collapse the month view, filter by category, and tap any day to see what's planned."
        case .trips:
            return "Budget, packing, itinerary, accommodation — all in one place. Share trips with friends and plan every detail together."
        case .settings:
            return "Turn on iCloud Sync to keep your data safe across devices. You can always replay this tour from here."
        case .complete:
            return "You're ready to plan your days and adventures. Let's get started."
        }
    }

    var icon: String {
        switch self {
        case .welcome:   return "airplane.circle.fill"
        case .dashboard: return "sun.max.fill"
        case .events:    return "star.circle.fill"
        case .calendar:  return "calendar.circle.fill"
        case .trips:     return "airplane.circle.fill"
        case .settings:  return "gearshape.circle.fill"
        case .complete:  return "party.popper.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome:   return .blue
        case .dashboard: return .orange
        case .events:    return .pink
        case .calendar:  return .purple
        case .trips:     return .blue
        case .settings:  return .gray
        case .complete:  return .yellow
        }
    }

    // MARK: - Behaviour

    var ctaLabel: String {
        self == .complete ? "Let's Go!" : "Next"
    }

    var targetTabIndex: Int? {
        switch self {
        case .welcome, .complete: return nil
        case .dashboard:          return 0
        case .events:             return 1
        case .calendar:           return 2
        case .trips:              return 3
        case .settings:           return 4
        }
    }

    /// Spotlight anchor — non-nil only when a specific UI element should be highlighted.
    /// The user is invited to tap it but not required to; every step has a "Next" button.
    var anchorId: String? {
        switch self {
        case .dashboard: return "anchor_dashboard_planmyday"
        case .events:    return "anchor_events_toolbar"
        case .calendar:  return "anchor_calendar_filter"
        case .trips:     return "anchor_trips_toolbar"
        case .settings:  return "anchor_settings_icloud"
        default:         return nil
        }
    }

    var isFullScreen: Bool {
        self == .welcome || self == .complete
    }

    /// Ordered steps shown inside the overlay — excludes the fullscreen welcome/complete bookends.
    static let tourSteps: [OnboardingStep] = allCases.filter { !$0.isFullScreen }

    /// Advances through every step including fullscreen bookends.
    var next: OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: self), idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }

    /// Steps back within tour steps only — the Back button never exits to a fullscreen step.
    var previous: OnboardingStep? {
        guard let idx = Self.tourSteps.firstIndex(of: self), idx > 0 else { return nil }
        return Self.tourSteps[idx - 1]
    }
}
