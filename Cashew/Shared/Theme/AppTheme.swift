import SwiftUI

// MARK: - App Colors

enum AppTheme {

    // MARK: - Primary Colors

    static let primaryGradient = LinearGradient(
        colors: [Color("AccentColor"), Color("AccentColor").opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let tripGradient = LinearGradient(
        colors: [.blue, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let eventGradient = LinearGradient(
        colors: [.purple, .pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let calendarGradient = LinearGradient(
        colors: [.orange, .red],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dayPlannerGradient = LinearGradient(
        colors: [.green, .mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Background Colors

    static let cardBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)

    // MARK: - Shadows

    static let cardShadow = Color.black.opacity(0.08)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4

    // MARK: - Corners

    static let cardCornerRadius: CGFloat = 16
    static let badgeCornerRadius: CGFloat = 8
    static let iconCornerRadius: CGFloat = 12

    // MARK: - Spacing

    static let cardPadding: CGFloat = 16
    static let listSpacing: CGFloat = 12

    // MARK: - Animation

    static let springResponse: Double = 0.35
    static let springDamping: Double = 0.7
    static let checkBounceScale: CGFloat = 1.35
    static let pulseRingDuration: Double = 1.4
    static let confettiDuration: Double = 0.45
    static let confettiFadeDuration: Double = 0.3
    static let confettiFadeDelay: Double = 0.35
    static let confettiLifetime: Double = 0.8
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(
                color: AppTheme.cardShadow,
                radius: AppTheme.cardShadowRadius,
                x: 0,
                y: AppTheme.cardShadowY
            )
    }
}

struct IconBackgroundStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.iconCornerRadius))
    }
}

struct GradientIconStyle: ViewModifier {
    let gradient: LinearGradient

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.iconCornerRadius))
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func iconBackground(_ color: Color) -> some View {
        modifier(IconBackgroundStyle(color: color))
    }

    func gradientIconBackground(_ gradient: LinearGradient) -> some View {
        modifier(GradientIconStyle(gradient: gradient))
    }
}
