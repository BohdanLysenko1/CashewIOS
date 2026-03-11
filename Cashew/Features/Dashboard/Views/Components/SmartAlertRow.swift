import SwiftUI

// MARK: - Urgency

enum SmartAlertUrgency {
    case critical   // needs action NOW
    case warning    // needs action today
    case info       // useful to know
}

// MARK: - Alert Type

enum SmartAlertType {

    // Time-sensitive
    case taskOverdue(taskTitle: String)
    case eventStartingSoon(eventName: String, minutesUntil: Int)
    case taskDueToday(taskTitle: String, dueTime: Date?)

    // Streak
    case streakAtRisk(routineName: String)

    // Trip
    case packingNeeded(tripName: String, itemsLeft: Int, daysUntil: Int)
    case budgetWarning(tripName: String, percentUsed: Int)
    case overdueChecklist(tripName: String, overdueCount: Int)
    case lowReadiness(tripName: String, readinessPercent: Int, daysUntil: Int)

    // Misc
    case noTasksToday

    // MARK: Urgency

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

    // MARK: Icon

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
        case .critical: return .red
        case .warning:  return .orange
        case .info:     return .blue
        }
    }

    // MARK: Text

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

    // MARK: Formatters

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    // MARK: Priority (lower = shown first)

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
}

// MARK: - Alert Row

struct SmartAlertRow: View {

    let alert: SmartAlertType

    var body: some View {
        HStack(spacing: 12) {
            iconBadge
            textStack
            Spacer(minLength: 4)
            urgencyIndicator
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 10)
        .background(rowBackground)
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(alert.iconColor.opacity(0.12))
                .frame(width: 40, height: 40)
            Image(systemName: alert.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(alert.iconColor)
        }
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(alert.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(alert.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var urgencyIndicator: some View {
        switch alert.urgency {
        case .critical:
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
        case .warning:
            Circle()
                .fill(Color.orange.opacity(0.7))
                .frame(width: 8, height: 8)
        case .info:
            EmptyView()
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if alert.urgency == .critical {
            Color.red.opacity(0.04)
        } else {
            Color.clear
        }
    }
}

// MARK: - Section

struct SmartAlertsSection: View {

    let alerts: [SmartAlertType]

    private var sortedAlerts: [SmartAlertType] {
        Array(alerts.sorted { $0.priority < $1.priority }.prefix(5))
    }

    private var hasCritical: Bool {
        sortedAlerts.contains { $0.urgency == .critical }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            Divider()
            alertList
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .stroke(hasCritical ? Color.red.opacity(0.25) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: hasCritical ? "bell.badge.fill" : "bell.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(hasCritical
                    ? AnyShapeStyle(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)))

            Text("Needs Attention")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            Text("\(sortedAlerts.count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(hasCritical ? Color.red : Color.orange)
                .clipShape(Circle())
        }
        .padding(AppTheme.cardPadding)
    }

    // MARK: List

    private var alertList: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedAlerts.enumerated()), id: \.offset) { index, alert in
                SmartAlertRow(alert: alert)
                if index < sortedAlerts.count - 1 {
                    Divider()
                        .padding(.leading, AppTheme.cardPadding + 52)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
