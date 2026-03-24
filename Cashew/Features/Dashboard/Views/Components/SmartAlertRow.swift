import SwiftUI

// MARK: - Urgency

enum SmartAlertUrgency {
    case critical
    case warning
    case info
}

// MARK: - Alert Type

enum SmartAlertType {

    case taskOverdue(taskTitle: String)
    case eventStartingSoon(eventName: String, minutesUntil: Int)
    case taskDueToday(taskTitle: String, dueTime: Date?)
    case streakAtRisk(routineName: String)
    case packingNeeded(tripName: String, itemsLeft: Int, daysUntil: Int)
    case budgetWarning(tripName: String, percentUsed: Int)
    case overdueChecklist(tripName: String, overdueCount: Int)
    case lowReadiness(tripName: String, readinessPercent: Int, daysUntil: Int)
    case noTasksToday

    var urgency: SmartAlertUrgency {
        switch self {
        case .taskOverdue:
            return .critical
        case .eventStartingSoon(_, let min):
            return min <= 30 ? .critical : .warning
        case .taskDueToday, .streakAtRisk, .overdueChecklist:
            return .warning
        case .budgetWarning, .lowReadiness, .packingNeeded, .noTasksToday:
            return .info
        }
    }

    var icon: String {
        switch self {
        case .taskOverdue:          return "clock.badge.exclamationmark.fill"
        case .eventStartingSoon:    return "bell.fill"
        case .taskDueToday:         return "calendar.badge.exclamationmark"
        case .streakAtRisk:         return "flame.fill"
        case .packingNeeded:        return "bag.fill"
        case .budgetWarning:        return "creditcard.fill"
        case .overdueChecklist:     return "exclamationmark.triangle.fill"
        case .lowReadiness:         return "gauge.with.dots.needle.33percent"
        case .noTasksToday:         return "plus.circle.fill"
        }
    }

    var iconColor: Color {
        switch urgency {
        case .critical: return AppTheme.tertiary
        case .warning:  return AppTheme.secondary
        case .info:     return AppTheme.primary
        }
    }

    var title: String {
        switch self {
        case .taskOverdue(let title):
            return "\(title) is overdue"
        case .eventStartingSoon(let name, let min):
            return min <= 0 ? "\(name) is starting now" : "\(name) in \(min) min"
        case .taskDueToday(let title, _):
            return "\(title) due today"
        case .streakAtRisk(let name):
            return "\(name) streak at risk"
        case .packingNeeded(let name, let items, let days):
            return "Pack \(items) item\(items == 1 ? "" : "s") for \(name) (\(days)d)"
        case .budgetWarning(let name, let percent):
            return "\(name) budget \(percent)% spent"
        case .overdueChecklist(let name, let count):
            return "\(count) overdue item\(count == 1 ? "" : "s") for \(name)"
        case .lowReadiness(let name, let percent, let days):
            return "\(name) only \(percent)% ready — \(days)d left"
        case .noTasksToday:
            return "No tasks planned today"
        }
    }

    var subtitle: String {
        switch self {
        case .taskOverdue:
            return "Mark complete or reschedule"
        case .eventStartingSoon(_, let min):
            return min <= 5 ? "Head out now!" : "Get ready"
        case .taskDueToday(_, let dueTime):
            if let dueTime {
                return "Due at \(Self.timeFormatter.string(from: dueTime))"
            }
            return "Complete before the day ends"
        case .streakAtRisk:
            return "Complete today to keep your streak"
        case .packingNeeded:
            return "Trip coming up soon"
        case .budgetWarning:
            return "Review your spending"
        case .overdueChecklist:
            return "Check your trip checklist"
        case .lowReadiness:
            return "Finalize your trip plans"
        case .noTasksToday:
            return "Add tasks to build momentum"
        }
    }

    var priority: Int {
        switch self {
        case .taskOverdue:                          return 0
        case .eventStartingSoon(_, let min):        return min <= 30 ? 1 : 2
        case .streakAtRisk:                         return 3
        case .taskDueToday:                         return 4
        case .overdueChecklist:                     return 5
        case .budgetWarning:                        return 6
        case .lowReadiness:                         return 7
        case .packingNeeded:                        return 8
        case .noTasksToday:                         return 9
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Section

struct SmartAlertsSection: View {

    let alerts: [SmartAlertType]

    private var sorted: [SmartAlertType] {
        Array(alerts.sorted { $0.priority < $1.priority }.prefix(4))
    }

    private var primary: SmartAlertType? { sorted.first }
    private var secondary: [SmartAlertType] { Array(sorted.dropFirst()) }

    var body: some View {
        VStack(spacing: 0) {
            if let primary {
                primaryAlert(primary)

                if !secondary.isEmpty {
                    ForEach(Array(secondary.enumerated()), id: \.offset) { index, alert in
                        secondaryRow(alert)
                    }
                }
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        // Urgency accent border on the left
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(primary?.iconColor ?? AppTheme.secondary)
                .frame(width: 3)
                .padding(.vertical, 1)
        }
    }

    // MARK: - Primary alert (top, featured)

    private func primaryAlert(_ alert: SmartAlertType) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: alert.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(alert.iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(AppTheme.TextStyle.bodyBold)
                    .foregroundStyle(AppTheme.onSurface)
                Text(alert.subtitle)
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 14)
        .background(alert.iconColor.opacity(0.07))
    }

    // MARK: - Secondary row (compact, no subtitle)

    private func secondaryRow(_ alert: SmartAlertType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: alert.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(alert.iconColor)
                .frame(width: 16)

            Text(alert.title)
                .font(AppTheme.TextStyle.caption)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 10)
    }
}
