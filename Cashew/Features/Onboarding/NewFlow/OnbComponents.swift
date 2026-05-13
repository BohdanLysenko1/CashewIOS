import SwiftUI

// MARK: - Floating background orbs

struct OnbOrb: View {
    enum Tint { case blue, purple, cyan, gold, pink }

    let tint: Tint
    var diameter: CGFloat = 240
    var blurRadius: CGFloat = 50
    var offset: CGSize? = nil
    var driftAmplitude: CGSize = CGSize(width: 20, height: -18)
    var driftPeriod: Double = 7

    @State private var driftPhase: CGSize = .zero

    var body: some View {
        Circle()
            .fill(tintColor)
            .frame(width: diameter, height: diameter)
            .blur(radius: blurRadius)
            .offset(x: defaultOffset.width + driftPhase.width,
                    y: defaultOffset.height + driftPhase.height)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: driftPeriod).repeatForever(autoreverses: true)) {
                    driftPhase = driftAmplitude
                }
            }
    }

    private var tintColor: Color {
        switch tint {
        case .blue:   return Color(red: 0.31, green: 0.43, blue: 1.0).opacity(0.32)
        case .purple: return Color(red: 0.66, green: 0.39, blue: 1.0).opacity(0.26)
        case .cyan:   return Color(red: 0.31, green: 0.78, blue: 1.0).opacity(0.20)
        case .gold:   return Color(red: 0.95, green: 0.79, blue: 0.30).opacity(0.30)
        case .pink:   return Color(red: 0.95, green: 0.49, blue: 0.77).opacity(0.25)
        }
    }

    private var defaultOffset: CGSize {
        if let offset { return offset }
        switch tint {
        case .blue:   return CGSize(width: -110, height: -160)
        case .purple: return CGSize(width: 130, height: 60)
        case .cyan:   return CGSize(width: -40, height: 220)
        case .gold:   return CGSize(width: 110, height: -180)
        case .pink:   return CGSize(width: -130, height: 180)
        }
    }
}

// MARK: - Progress dots

struct OnbProgressDots: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(fill(for: i))
                    .frame(width: i == step ? 32 : 18, height: 4)
                    .animation(.easeInOut(duration: 0.4), value: step)
            }
        }
    }

    private func fill(for i: Int) -> Color {
        if i == step { return .white }
        if i < step  { return Color.white.opacity(0.55) }
        return Color.white.opacity(0.20)
    }
}

// MARK: - Skip bar

struct OnbSkipBar: View {
    var onSkip: (() -> Void)?

    var body: some View {
        HStack {
            Spacer()
            if let onSkip {
                Button("Skip", action: onSkip)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                Color.clear.frame(width: 40, height: 36)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Bottom navigation (back + dots)

struct OnbBottomNav: View {
    let step: Int
    let total: Int
    var onBack: (() -> Void)?

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            Spacer()
            OnbProgressDots(step: step, total: total)
            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 8)
    }
}

// MARK: - Eyebrow chip

struct OnbEyebrow: View {
    let text: String
    var icon: String? = nil
    var goldStyle: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
            }
            Text(text)
                .font(OnbTheme.eyebrow())
                .tracking(1.4)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(borderColor, lineWidth: 1))
    }

    private var foreground: Color {
        goldStyle ? Color(red: 1.0, green: 0.90, blue: 0.58) : Color.white.opacity(0.62)
    }
    private var background: Color {
        goldStyle ? OnbTheme.premiumGold.opacity(0.18) : Color.white.opacity(0.08)
    }
    private var borderColor: Color {
        goldStyle ? OnbTheme.premiumGold.opacity(0.35) : Color.white.opacity(0.14)
    }
}

// MARK: - Primary CTA button

struct OnbPrimaryButton: View {
    enum Variant { case white, gold }

    let title: String
    var trailingIcon: String? = "arrow.right"
    var variant: Variant = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 14, weight: .heavy))
                }
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if variant == .gold {
                    OnbTheme.premiumGradient
                } else {
                    OnbTheme.primaryCTAGradient
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: shadow, radius: 22, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        variant == .gold ? OnbTheme.inkOnGold : OnbTheme.darkInk
    }

    private var shadow: Color {
        variant == .gold ? OnbTheme.premiumAmber.opacity(0.45) : Color.white.opacity(0.30)
    }
}

struct OnbGhostButton: View {
    let title: String
    var trailingTitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if let trailingTitle {
                    Text(trailingTitle)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lock badge ("Premium")

struct OnbLockBadge: View {
    var label: String = "Premium"

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .heavy))
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle(OnbTheme.inkOnGold)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(OnbTheme.premiumGradient)
        .clipShape(Capsule())
        .shadow(color: OnbTheme.premiumAmber.opacity(0.45), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Sparkle star (gold)

struct OnbSparkle: View {
    var size: CGFloat = 14
    var color: Color = OnbTheme.premiumGold

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .black))
            .foregroundStyle(color)
    }
}

// MARK: - Pulse ring (used behind welcome logo)

struct OnbPulseRing: View {
    var delay: Double = 0
    var color: Color = Color(red: 0.56, green: 0.59, blue: 1.00).opacity(0.5)

    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(animate ? 1.4 : 0.95)
            .opacity(animate ? 0 : 0.7)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) {
                        animate = true
                    }
                }
            }
    }
}

// MARK: - Chip (welcome screen feature pills)

struct OnbChip: View {
    let icon: String
    let text: String
    var goldStyle: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(goldStyle ? Color(red: 1.0, green: 0.90, blue: 0.58) : Color.white.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(chipBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(goldStyle
                ? OnbTheme.premiumGold.opacity(0.42)
                : Color.white.opacity(0.16),
                lineWidth: 1)
        )
    }

    @ViewBuilder
    private var chipBackground: some View {
        if goldStyle {
            LinearGradient(
                colors: [OnbTheme.premiumGold.opacity(0.22), OnbTheme.premiumAmber.opacity(0.22)],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            Color.white.opacity(0.12)
        }
    }
}

// MARK: - Mini pill (used inside light event cards)

struct OnbMiniPill: View {
    let icon: String
    let text: String
    var accent: Color? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(accent ?? Color(red: 0.40, green: 0.41, blue: 0.42))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((accent.map { $0.opacity(0.12) } ?? Color(red: 0.95, green: 0.95, blue: 0.96)))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Frosted preview card (used to wrap UI mocks)

struct OnbPreviewCard<Background: View, Content: View>: View {
    var borderColor: Color = Color.white.opacity(0.10)
    var padding: CGFloat = 16
    @ViewBuilder var background: () -> Background
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(background())
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

extension OnbPreviewCard where Background == Color {
    init(borderColor: Color = Color.white.opacity(0.10),
         padding: CGFloat = 16,
         backgroundOpacity: Double = 0.06,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(borderColor: borderColor, padding: padding,
                  background: { Color.white.opacity(backgroundOpacity) },
                  content: content)
    }
}

// MARK: - Title + subtitle block

struct OnbTextBlock<EyebrowContent: View>: View {
    @ViewBuilder var eyebrow: () -> EyebrowContent
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            eyebrow()
            Text(title)
                .font(OnbTheme.title(28))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text(rendered(subtitle))
                .font(OnbTheme.subtitle())
                .foregroundStyle(Color.white.opacity(0.70))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 4)
        }
    }

    private func rendered(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }
}
