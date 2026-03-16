import SwiftUI

struct WelcomeScreenView: View {

    let onStart: () -> Void
    let onSkip: () -> Void

    // Entrance animation states
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoPulse: Bool = false
    @State private var titleOffset: CGFloat = 28
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    // Orb entrance + continuous float states
    @State private var orb1Pos = CGSize(width: -30, height: -60)
    @State private var orb2Pos = CGSize(width: 60, height: -20)
    @State private var orb3Pos = CGSize(width: -20, height: 50)
    @State private var orbOpacity: Double = 0
    @State private var orb1Float: CGSize = .zero
    @State private var orb2Float: CGSize = .zero
    @State private var orb3Float: CGSize = .zero

    @State private var hasAnimated = false

    // Staggered pill entrance
    @State private var pill1Opacity: Double = 0
    @State private var pill2Opacity: Double = 0
    @State private var pill3Opacity: Double = 0
    @State private var pill1Offset: CGFloat = 12
    @State private var pill2Offset: CGFloat = 12
    @State private var pill3Offset: CGFloat = 12

    var body: some View {
        ZStack {
            // Background
            AppTheme.onboardingBackground
                .ignoresSafeArea()

            // Floating orbs — entrance position + continuous float offset
            Circle()
                .fill(Color.blue.opacity(0.20))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: orb1Pos.width + orb1Float.width,
                        y: orb1Pos.height + orb1Float.height)
                .opacity(orbOpacity)

            Circle()
                .fill(Color.purple.opacity(0.16))
                .frame(width: 190, height: 190)
                .blur(radius: 42)
                .offset(x: orb2Pos.width + orb2Float.width,
                        y: orb2Pos.height + orb2Float.height)
                .opacity(orbOpacity)

            Circle()
                .fill(Color.cyan.opacity(0.13))
                .frame(width: 150, height: 150)
                .blur(radius: 36)
                .offset(x: orb3Pos.width + orb3Float.width,
                        y: orb3Pos.height + orb3Float.height)
                .opacity(orbOpacity)

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Logo with glow ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color.blue.opacity(0.28))
                        .frame(width: 170, height: 170)
                        .blur(radius: 28)

                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 132, height: 132)

                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 110, height: 110)

                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 0.70, green: 0.86, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .scaleEffect(logoPulse ? 1.025 : 1.0)
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: logoPulse)

                Spacer().frame(height: 40)

                // Title
                Text("Welcome to Cashew")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Spacer().frame(height: 14)

                // Subtitle
                Text("Plan your day, track events,\nand organize every trip.")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .opacity(subtitleOpacity)

                Spacer()

                // Feature pills — staggered slide-up
                HStack(spacing: 11) {
                    FeaturePill(icon: "airplane", label: "Trips")
                        .opacity(pill1Opacity)
                        .offset(y: pill1Offset)

                    FeaturePill(icon: "star.fill", label: "Events")
                        .opacity(pill2Opacity)
                        .offset(y: pill2Offset)

                    FeaturePill(icon: "checklist", label: "Tasks")
                        .opacity(pill3Opacity)
                        .offset(y: pill3Offset)
                }

                Spacer().frame(height: 44)

                // CTA
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Text("Start Tour")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.white, Color(red: 0.84, green: 0.92, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .white.opacity(0.22), radius: 22, y: 5)
                }
                .padding(.horizontal, 32)
                .opacity(buttonOpacity)

                Spacer().frame(height: 16)

                Button("Skip Tour", action: onSkip)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .opacity(buttonOpacity)

                Spacer().frame(height: 44)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            animateIn()
        }
    }

    private func animateIn() {
        // Orb entrance
        withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
            orbOpacity = 1
            orb1Pos = CGSize(width: -90, height: -130)
            orb2Pos = CGSize(width: 105, height: -65)
            orb3Pos = CGSize(width: -55, height: 85)
        }

        // Logo bounce in
        withAnimation(.spring(response: 0.72, dampingFraction: 0.58).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1
        }

        // Title slide up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.52)) {
            titleOffset = 0
            titleOpacity = 1
        }

        // Subtitle fade
        withAnimation(.easeOut(duration: 0.5).delay(0.78)) {
            subtitleOpacity = 1
        }

        // Pills — staggered slide-up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.88)) {
            pill1Opacity = 1; pill1Offset = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(1.02)) {
            pill2Opacity = 1; pill2Offset = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(1.16)) {
            pill3Opacity = 1; pill3Offset = 0
        }

        // Buttons fade in
        withAnimation(.easeOut(duration: 0.5).delay(1.05)) {
            buttonOpacity = 1
        }

        // Start logo breath + orb float after entrance settles
        Task {
            try? await Task.sleep(for: .milliseconds(1600))

            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                logoPulse = true
            }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                orb1Float = CGSize(width: 22, height: -16)
            }
            withAnimation(.easeInOut(duration: 5.4).repeatForever(autoreverses: true)) {
                orb2Float = CGSize(width: -18, height: 22)
            }
            withAnimation(.easeInOut(duration: 3.9).repeatForever(autoreverses: true)) {
                orb3Float = CGSize(width: 14, height: 10)
            }
        }
    }
}

// MARK: - Feature Pill

private struct FeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.white.opacity(0.78))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.11))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}
