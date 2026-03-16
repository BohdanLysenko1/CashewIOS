import SwiftUI

// MARK: - App Colors

enum AppTheme {

    // MARK: - Primary Colors

    static let primaryGradient = LinearGradient(
        colors: [Color("AccentColor"), Color("AccentColor").opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Blue — Tasks, planning, productivity
    static let dayPlannerGradient = LinearGradient(
        colors: [.blue, .indigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Orange — Trips, travel, adventure
    static let tripGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 0.95, green: 0.35, blue: 0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Pink — Events, social
    static let eventGradient = LinearGradient(
        colors: [.pink, Color(red: 0.9, green: 0.2, blue: 0.45)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Purple — Achievement, XP, levels, streaks
    static let gamificationGradient = LinearGradient(
        colors: [.purple, .indigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let calendarGradient = LinearGradient(
        colors: [.orange, .red],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Background Colors

    /// Deep navy/indigo — shared by the onboarding welcome and completion screens.
    static let onboardingBackground = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.07, blue: 0.20),
            Color(red: 0.10, green: 0.04, blue: 0.26),
            Color(red: 0.03, green: 0.11, blue: 0.23)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

    // MARK: - Spacing Scale (4pt base grid)

    enum Space {
        static let xxs: CGFloat = 2   // hairlines, tight insets
        static let xs:  CGFloat = 4   // icon gaps, micro padding
        static let sm:  CGFloat = 8   // small component gaps
        static let md:  CGFloat = 12  // list row spacing, inner card gaps
        static let lg:  CGFloat = 16  // card padding, section gaps
        static let xl:  CGFloat = 20  // hero section padding
        static let xxl: CGFloat = 24  // between major sections
        static let xxxl: CGFloat = 32 // top-level scroll padding
    }

    // Semantic aliases — use these in views
    static let cardPadding: CGFloat  = Space.lg   // 16
    static let listSpacing: CGFloat  = Space.md   // 12

    // MARK: - Progress Bars

    static let progressBarHeight: CGFloat = 6
    static let progressBarCornerRadius: CGFloat = 3

    // MARK: - Stat Tiles

    static let statTileCornerRadius: CGFloat = 12
    static let statTileBackgroundOpacity: Double = 0.08
    static let statTileBorderOpacity: Double = 0.15

    // MARK: - Typography

    enum TextStyle {
        // Display
        static let heroTitle:    Font = .system(size: 28, weight: .black)
        static let title:        Font = .system(size: 20, weight: .bold)
        static let sectionTitle: Font = .system(size: 17, weight: .bold)

        // Body
        static let bodyBold:     Font = .system(size: 15, weight: .semibold)
        static let body:         Font = .system(size: 15, weight: .regular)
        static let secondary:    Font = .system(size: 13, weight: .regular)

        // Caption
        static let captionBold:  Font = .system(size: 11, weight: .semibold)
        static let caption:      Font = .system(size: 11, weight: .regular)
        static let micro:        Font = .system(size: 9,  weight: .medium)

        // Label (monospaced for numbers)
        static let statLarge:    Font = .system(size: 28, weight: .black).monospacedDigit()
        static let statMedium:   Font = .system(size: 20, weight: .bold).monospacedDigit()
        static let statSmall:    Font = .system(size: 15, weight: .semibold).monospacedDigit()
    }

    // MARK: - Section Headers

    static let sectionIconSize: CGFloat = 16

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

// MARK: - Shared Dashboard Components

/// Consistent section-header row used at the top of every dashboard card.
struct SectionHeader: View {
    let icon: String
    let title: String
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: AppTheme.sectionIconSize, weight: .semibold))
                .foregroundStyle(gradient)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
    }
}

/// Single consistent progress bar used across all dashboard cards.
struct AppProgressBar: View {
    let progress: Double   // 0…1
    let color: Color
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppTheme.progressBarCornerRadius)
                    .fill(color.opacity(0.15))

                RoundedRectangle(cornerRadius: AppTheme.progressBarCornerRadius)
                    .fill(color.gradient)
                    .frame(width: geo.size.width * min(1, max(0, progress)))
                    .animation(animated ? .spring(response: 0.5) : nil, value: progress)
            }
        }
        .frame(height: AppTheme.progressBarHeight)
    }
}
