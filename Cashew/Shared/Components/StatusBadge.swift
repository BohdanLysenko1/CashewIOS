import SwiftUI

struct StatusBadge: View {
    let status: TripStatus
    var style: BadgeStyle = .default

    enum BadgeStyle {
        case `default`
        case prominent
        case onGradient
    }

    var body: some View {
        HStack(spacing: 4) {
            if style == .prominent || style == .onGradient {
                Circle()
                    .fill(style == .onGradient ? Color.white : status.color)
                    .frame(width: 6, height: 6)
            }
            Text(status.displayName)
                .font(AppTheme.TextStyle.captionBold)
        }
        .padding(.horizontal, style == .default ? 8 : 10)
        .padding(.vertical, style == .default ? 4 : 5)
        .background(style == .onGradient ? Color.white.opacity(0.20) : status.color.opacity(0.15))
        .foregroundStyle(style == .onGradient ? Color.white : status.color)
        .clipShape(Capsule())
    }
}

// MARK: - TripStatus Color Extension

extension TripStatus {
    var color: Color {
        switch self {
        case .planning: AppTheme.primary
        case .upcoming: AppTheme.secondary
        case .active: Color(red: 0.20, green: 0.72, blue: 0.45)
        case .completed: AppTheme.onSurfaceVariant
        case .cancelled: AppTheme.tertiary
        }
    }

    var icon: String {
        switch self {
        case .planning: "pencil.and.list.clipboard"
        case .upcoming: "calendar.badge.clock"
        case .active: "airplane.departure"
        case .completed: "checkmark.circle"
        case .cancelled: "xmark.circle"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack {
            StatusBadge(status: .planning)
            StatusBadge(status: .upcoming)
            StatusBadge(status: .active)
        }
        HStack {
            StatusBadge(status: .planning, style: .prominent)
            StatusBadge(status: .active, style: .prominent)
            StatusBadge(status: .completed, style: .prominent)
        }
    }
    .padding()
}
