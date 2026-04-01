import SwiftUI

// MARK: - Design Tokens  (The Luminous Productivity Framework)

enum AppTheme {

    private static var isDark: Bool { AppearanceManager.shared.isDark }

    // ─────────────────────────────────────────────
    // MARK: - Color Palette
    // ─────────────────────────────────────────────

    // Primary
    static var primary: Color {
        isDark
            ? Color(red: 0.48, green: 0.52, blue: 1.00)   // #7B85FF
            : Color(red: 0.21, green: 0.26, blue: 0.91)   // #3642E9
    }
    static var primaryDim: Color {
        isDark
            ? Color(red: 0.35, green: 0.32, blue: 0.88)   // #5A52E0
            : Color(red: 0.20, green: 0.18, blue: 0.78)   // #332DC7
    }
    static var primaryContainer: Color {
        isDark
            ? Color(red: 0.23, green: 0.26, blue: 0.63)   // #3A42A0
            : Color(red: 0.56, green: 0.59, blue: 1.00)   // #8F97FF
    }
    static let onPrimary = Color.white

    // Secondary — used to distinguish "Trips"
    static var secondary: Color {
        isDark
            ? Color(red: 0.69, green: 0.48, blue: 1.00)   // #B07AFF
            : Color(red: 0.45, green: 0.21, blue: 0.80)   // #7335CC
    }
    static var secondaryContainer: Color {
        isDark
            ? Color(red: 0.29, green: 0.18, blue: 0.50)   // #4A2D80
            : Color(red: 0.60, green: 0.40, blue: 0.90)
    }

    // Tertiary — used to distinguish "Events", rewards, streaks, XP
    static var tertiary: Color {
        isDark
            ? Color(red: 0.82, green: 0.42, blue: 0.69)   // #D06AAF
            : Color(red: 0.58, green: 0.22, blue: 0.48)   // #95377A
    }
    static var tertiaryContainer: Color {
        isDark
            ? Color(red: 0.42, green: 0.18, blue: 0.33)   // #6B2D55
            : Color(red: 0.75, green: 0.40, blue: 0.62)
    }

    // Neutral / Surface hierarchy  ("layers of fine paper")
    static var background: Color {
        isDark
            ? Color(red: 0.07, green: 0.07, blue: 0.08)   // #121214
            : Color(red: 0.96, green: 0.96, blue: 0.97)   // #F5F6F7
    }
    static var surface: Color {
        isDark
            ? Color(red: 0.10, green: 0.10, blue: 0.12)   // #1A1A1E
            : Color(red: 0.97, green: 0.97, blue: 0.98)
    }
    static var surfaceContainerLow: Color {
        isDark
            ? Color(red: 0.12, green: 0.12, blue: 0.13)   // #1E1E22
            : Color(red: 0.95, green: 0.95, blue: 0.96)
    }
    static var surfaceContainer: Color {
        isDark
            ? Color(red: 0.14, green: 0.14, blue: 0.16)   // #242428
            : Color(red: 0.93, green: 0.93, blue: 0.95)
    }
    static var surfaceContainerHigh: Color {
        isDark
            ? Color(red: 0.17, green: 0.17, blue: 0.20)   // #2C2C32
            : Color(red: 0.90, green: 0.90, blue: 0.92)
    }
    static var surfaceContainerLowest: Color {
        isDark
            ? Color(red: 0.06, green: 0.06, blue: 0.07)   // #0F0F12
            : Color.white
    }

    // On-surface text  (never use pure #000000)
    static var onSurface: Color {
        isDark
            ? Color(red: 0.89, green: 0.89, blue: 0.91)   // #E4E4E8
            : Color(red: 0.17, green: 0.18, blue: 0.19)   // #2C2F30
    }
    static var onSurfaceVariant: Color {
        isDark
            ? Color(red: 0.63, green: 0.64, blue: 0.67)   // #A0A4AA
            : Color(red: 0.40, green: 0.42, blue: 0.44)
    }
    static var outlineVariant: Color {
        isDark
            ? onSurface.opacity(0.12)
            : onSurface.opacity(0.10)
    }

    // ─────────────────────────────────────────────
    // MARK: - Gradients
    // ─────────────────────────────────────────────

    // "Moments of Action" — hero CTAs, active states
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryContainer],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Tasks, planning, productivity  (uses primary range)
    static var dayPlannerGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryDim],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Trips, travel — secondary accent
    static var tripGradient: LinearGradient {
        LinearGradient(
            colors: [secondary, secondaryContainer],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Events, social — tertiary accent
    static var eventGradient: LinearGradient {
        LinearGradient(
            colors: [tertiary, tertiaryContainer],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Achievement, XP, levels, streaks — tertiary range per design "DO" rule
    static var gamificationGradient: LinearGradient {
        LinearGradient(
            colors: [tertiary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var calendarGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Signature "Mission / Hero" card fill
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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

    // ─────────────────────────────────────────────
    // MARK: - Surface Shortcuts (backward-compatible)
    // ─────────────────────────────────────────────

    static var cardBackground: Color { surfaceContainerLowest }
    static var secondaryBackground: Color { surfaceContainerLow }

    // ─────────────────────────────────────────────
    // MARK: - Elevation & Shadows
    //   "Tonal Layering, not heavy drop shadows"
    //   Signature Glow: on_surface 6%, blur 32-48, y 8
    // ─────────────────────────────────────────────

    static var cardShadow: Color {
        isDark ? Color.clear : onSurface.opacity(0.06)
    }
    static let cardShadowRadius: CGFloat = 32
    static let cardShadowY: CGFloat = 8

    // ─────────────────────────────────────────────
    // MARK: - Corner Radii
    //   md = 1.5rem ≈ 24pt   (primary cards)
    //   lg = 2rem   ≈ 32pt   (main container wrappers)
    //   xl = 3rem   ≈ 48pt   (primary buttons)
    // ─────────────────────────────────────────────

    static let cardCornerRadius: CGFloat = 24
    static let containerCornerRadius: CGFloat = 32
    static let buttonCornerRadius: CGFloat = 48
    static let badgeCornerRadius: CGFloat = 12
    static let iconCornerRadius: CGFloat = 16

    // ─────────────────────────────────────────────
    // MARK: - Spacing Scale (4pt base grid)
    // ─────────────────────────────────────────────

    enum Space {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        // Design-doc large whitespace tokens
        static let sectionBreak: CGFloat = 56   // ~7rem — use between major sections
        static let heroBreak: CGFloat = 68      // ~8.5rem
    }

    // Semantic aliases
    static let cardPadding: CGFloat  = Space.lg
    static let listSpacing: CGFloat  = Space.md
    // "spacing-4 (1.4rem)" from design doc → use inside cards instead of Dividers
    static let cardInternalSpacing: CGFloat = 22

    // ─────────────────────────────────────────────
    // MARK: - Progress Bars
    // ─────────────────────────────────────────────

    static let progressBarHeight: CGFloat = 6
    static let progressBarCornerRadius: CGFloat = 3

    // ─────────────────────────────────────────────
    // MARK: - Stat Tiles (no border — tonal only)
    // ─────────────────────────────────────────────

    static let statTileCornerRadius: CGFloat = 16
    static let statTileBackgroundOpacity: Double = 0.08
    static let statTileBorderOpacity: Double = 0.0  // "No-Line" rule

    // ─────────────────────────────────────────────
    // MARK: - Typography
    //   Display & Headlines: Plus Jakarta Sans  (fallback: .rounded system)
    //   Body & Labels: Inter  (fallback: default system / SF Pro)
    //   3:1 ratio between headline and body sizes
    // ─────────────────────────────────────────────

    enum TextStyle {
        // Display — Plus Jakarta Sans feel (rounded, tight tracking)
        static let displayLarge: Font = .system(size: 36, weight: .black, design: .rounded)
        static let heroTitle:    Font = .system(size: 28, weight: .black, design: .rounded)
        static let title:        Font = .system(size: 22, weight: .bold, design: .rounded)
        static let sectionTitle: Font = .system(size: 17, weight: .bold, design: .rounded)

        // Body — Inter feel (default SF Pro is very close to Inter)
        static let bodyLarge:    Font = .system(size: 17, weight: .regular)
        static let bodyBold:     Font = .system(size: 15, weight: .semibold)
        static let body:         Font = .system(size: 15, weight: .regular)
        static let secondary:    Font = .system(size: 13, weight: .regular)

        // Caption / Label
        static let captionBold:  Font = .system(size: 11, weight: .semibold)
        static let caption:      Font = .system(size: 11, weight: .regular)
        static let micro:        Font = .system(size: 9,  weight: .medium)

        // Stats (monospaced digits)
        static let statLarge:    Font = .system(size: 28, weight: .black, design: .rounded).monospacedDigit()
        static let statMedium:   Font = .system(size: 20, weight: .bold, design: .rounded).monospacedDigit()
        static let statSmall:    Font = .system(size: 15, weight: .semibold).monospacedDigit()
    }

    // ─────────────────────────────────────────────
    // MARK: - Section Headers
    // ─────────────────────────────────────────────

    static let sectionIconSize: CGFloat = 16

    // ─────────────────────────────────────────────
    // MARK: - Animation
    // ─────────────────────────────────────────────

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
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                colorScheme == .dark
                    ? AnyShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                        .stroke(AppTheme.onSurface.opacity(0.08), lineWidth: 0.5)
                    : nil
            )
            .shadow(
                color: AppTheme.cardShadow,
                radius: AppTheme.cardShadowRadius,
                x: 0,
                y: AppTheme.cardShadowY
            )
    }
}

/// Glassmorphism modifier per design spec:
/// surface_container_lowest 80% opacity + 20px backdrop blur.
struct GlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(AppTheme.surfaceContainerLowest.opacity(0.80))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
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
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.iconCornerRadius, style: .continuous))
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
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.iconCornerRadius, style: .continuous))
    }
}

/// Input field container per design spec:
/// surface_container background, no border. On focus → surface_container_lowest + ghost border.
struct DesignFieldStyle: ViewModifier {
    var isFocused: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(isFocused ? AppTheme.surfaceContainerLowest : AppTheme.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(isFocused ? AppTheme.primary.opacity(0.20) : .clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func glassStyle() -> some View {
        modifier(GlassStyle())
    }

    func iconBackground(_ color: Color) -> some View {
        modifier(IconBackgroundStyle(color: color))
    }

    func gradientIconBackground(_ gradient: LinearGradient) -> some View {
        modifier(GradientIconStyle(gradient: gradient))
    }

    func designField(isFocused: Bool = false) -> some View {
        modifier(DesignFieldStyle(isFocused: isFocused))
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
                .font(AppTheme.TextStyle.sectionTitle)
                .foregroundStyle(AppTheme.onSurface)
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
