import SwiftUI

struct AppFilterSection<Content: View>: View {
    let title: String
    let activeCount: Int
    let onClear: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        activeCount: Int = 0,
        onClear: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.activeCount = activeCount
        self.onClear = onClear
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
            HStack(spacing: AppTheme.Space.sm) {
                Text(title)
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .textCase(.uppercase)
                    .tracking(0.5)

                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.primary)
                        .clipShape(Capsule())
                }

                Spacer()

                if activeCount > 0, let onClear {
                    Button("Clear", action: onClear)
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.negative)
                }
            }

            content()
        }
        .padding(AppTheme.Space.lg)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: 6)
    }
}

struct AppFilterChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let tint: Color
    let selectedGradient: LinearGradient?
    let action: () -> Void

    init(
        label: String,
        icon: String? = nil,
        isSelected: Bool,
        tint: Color = AppTheme.primary,
        selectedGradient: LinearGradient? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.isSelected = isSelected
        self.tint = tint
        self.selectedGradient = selectedGradient
        self.action = action
    }

    private var selectedStyle: AnyShapeStyle {
        if let selectedGradient {
            return AnyShapeStyle(selectedGradient)
        }
        return AnyShapeStyle(tint)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(label)
                    .font(AppTheme.TextStyle.secondary)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? selectedStyle : AnyShapeStyle(AppTheme.surfaceContainerLow))
            .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : AppTheme.surfaceContainerHigh,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct AppFilterToggleTile: View {
    let label: String
    let icon: String
    let isOn: Bool
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppTheme.Space.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn ? tint : AppTheme.onSurfaceVariant)

                Text(label)
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(isOn ? tint : AppTheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Space.lg)
            .background(isOn ? tint.opacity(0.12) : AppTheme.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? tint.opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
