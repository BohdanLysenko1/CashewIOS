import SwiftUI

struct TripModuleCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
            )
            .shadow(color: AppTheme.cardShadow, radius: 14, x: 0, y: 5)
    }
}

extension View {
    func tripModuleCard() -> some View {
        modifier(TripModuleCardStyle())
    }

    func tripSoftSurface(cornerRadius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(AppTheme.surfaceContainerLow)
            .clipShape(shape)
            .overlay(
                shape
                    .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
            )
    }
}

struct TripSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    init(_ title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            SectionHeader(icon: icon, title: title, gradient: AppTheme.tripGradient)
            content
        }
        .padding(AppTheme.Space.lg)
        .tripModuleCard()
    }
}

struct TripHeroCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(icon: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            HStack(spacing: AppTheme.Space.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.TextStyle.title)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(AppTheme.TextStyle.secondary)
                        .foregroundStyle(.white.opacity(0.82))
                }
            }

            content
        }
        .padding(AppTheme.Space.lg)
        .background(AppTheme.tripGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: AppTheme.secondary.opacity(0.26), radius: 18, x: 0, y: 8)
    }
}

struct TripMetricPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTheme.TextStyle.caption)
                .foregroundStyle(.white.opacity(0.78))
            Text(value)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
