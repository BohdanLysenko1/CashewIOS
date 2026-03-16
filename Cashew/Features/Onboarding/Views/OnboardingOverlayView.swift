import SwiftUI

struct OnboardingOverlayView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var cardOffset: CGFloat = Layout.cardEntryOffset
    @State private var cardOpacity: Double = 0

    private enum Layout {
        /// How far below its resting position the card starts before animating in.
        static let cardEntryOffset: CGFloat = 64
        /// Gap between the card's bottom edge and the top of the tab bar.
        static let cardTabBarClearance: CGFloat = 60
    }

    private var highlightFrame: CGRect {
        coordinator.currentHighlightFrame ?? .zero
    }

    private var hasHighlight: Bool {
        coordinator.currentHighlightFrame != nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dim — spotlight cutout for action-hint steps, soft dim otherwise
                if hasHighlight {
                    SpotlightLayer(screenSize: geo.size, highlightFrame: highlightFrame)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    PulsingRing(frame: highlightFrame)
                        .id(coordinator.currentStep)
                } else {
                    Color.black.opacity(0.52)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // Card + optional upward arrow, pinned above the tab bar
                VStack(spacing: 0) {
                    Spacer().allowsHitTesting(false)

                    VStack(spacing: 0) {
                        // Arrow that draws the eye toward the spotlight element.
                        // Suppressed when the highlight is level with or below the card
                        // (i.e., its bottom edge reaches the card's bottom anchor),
                        // since pointing up toward something below the card misleads.
                        let cardBottomAnchor = geo.size.height - geo.safeAreaInsets.bottom - Layout.cardTabBarClearance
                        if hasHighlight && highlightFrame.maxY < cardBottomAnchor {
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(coordinator.currentStep.iconColor.opacity(0.75))
                                .padding(.bottom, 6)
                        }

                        TooltipCard(
                            step: coordinator.currentStep,
                            onBack: { coordinator.goBack() },
                            onNext: { coordinator.advance() }
                        )
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + Layout.cardTabBarClearance)
                    .offset(y: cardOffset)
                    .opacity(cardOpacity)
                }

            }
        }
        .ignoresSafeArea()
        .onAppear { animateCardIn() }
        .onChange(of: coordinator.currentStep) { _, _ in
            resetCard()
            Task { @MainActor in animateCardIn() }
        }
    }

    private func animateCardIn() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            cardOffset = 0
            cardOpacity = 1
        }
    }

    private func resetCard() {
        cardOffset = Layout.cardEntryOffset
        cardOpacity = 0
    }
}

// MARK: - Pulsing Ring (own animation lifecycle — doesn't reset on step change)

private struct PulsingRing: View {
    let frame: CGRect
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.65

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white.opacity(opacity), lineWidth: 2)
            .frame(width: frame.width + 22, height: frame.height + 22)
            .position(x: frame.midX, y: frame.midY)
            .scaleEffect(scale)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.08
                    opacity = 0.15
                }
            }
    }
}

// MARK: - Spotlight Layer

private struct SpotlightLayer: View {
    let screenSize: CGSize
    let highlightFrame: CGRect

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.74)))
            ctx.blendMode = .clear
            ctx.fill(
                Path(roundedRect: highlightFrame.insetBy(dx: -12, dy: -12),
                     cornerRadii: .init(topLeading: 20, bottomLeading: 20,
                                        bottomTrailing: 20, topTrailing: 20)),
                with: .color(.white)
            )
        }
        .compositingGroup()
        .frame(width: screenSize.width, height: screenSize.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Tooltip Card

private struct TooltipCard: View {
    let step: OnboardingStep
    let onBack: () -> Void
    let onNext: () -> Void

    private var accent: Color { step.iconColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepDots(current: step)
            StepHeader(step: step)

            Text(step.subtitle)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            StepFooter(step: step, onBack: onBack, onNext: onNext)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [accent.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.35), value: step)
    }
}

// Step dot-pill row — each dot is a Capsule; active is wider + accent-coloured
private struct StepDots: View {
    let current: OnboardingStep
    private let inner = OnboardingStep.tourSteps

    var body: some View {
        HStack(spacing: 6) {
            ForEach(inner) { s in
                let active = s == current
                Capsule()
                    .fill(active ? current.iconColor : Color.white.opacity(0.18))
                    .frame(width: active ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: current)
            }
            Spacer()
        }
    }
}

// Icon-in-bubble + title
private struct StepHeader: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: step.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(step.iconColor)
                    .symbolEffect(.bounce, value: step)
            }
            Text(step.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// Counter + Back + Next button row
private struct StepFooter: View {
    let step: OnboardingStep
    let onBack: () -> Void
    let onNext: () -> Void
    private let inner = OnboardingStep.tourSteps

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Back button — only shown when there's a previous step
            if step.previous != nil {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
            }

            // Step counter
            if let idx = inner.firstIndex(of: step) {
                Text(String(localized: "\(idx + 1) of \(inner.count)",
                            comment: "Onboarding step counter — first number is current step, second is total"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            Spacer()

            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text(step.ctaLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(step.iconColor)
                .clipShape(Capsule())
                .shadow(color: step.iconColor.opacity(0.45), radius: 8, y: 3)
            }
        }
    }
}
