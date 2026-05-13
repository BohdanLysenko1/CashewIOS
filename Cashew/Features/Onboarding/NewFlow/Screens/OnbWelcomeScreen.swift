import SwiftUI

struct OnbWelcomeScreen: View {

    let onNext: () -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        ZStack {
            OnbTheme.pageBackground.ignoresSafeArea()

            ZStack {
                OnbOrb(tint: .blue, diameter: 280, blurRadius: 50)
                OnbOrb(tint: .purple, diameter: 220, blurRadius: 50)
                OnbOrb(tint: .cyan, diameter: 180, blurRadius: 50,
                       offset: CGSize(width: -60, height: 220))
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbSkipBar(onSkip: onClose)

                Spacer()

                logoStage
                    .padding(.bottom, 32)

                OnbTextBlock(
                    eyebrow: { OnbEyebrow(text: "Your everyday co-pilot", icon: "sparkle") },
                    title: "Plan your day.\nTrack every trip.",
                    subtitle: "Cashew brings tasks, events, and adventures into one beautifully calm app — supercharged with AI."
                )
                .padding(.horizontal, 24)

                HStack(spacing: 8) {
                    OnbChip(icon: "checklist", text: "Tasks")
                    OnbChip(icon: "star.fill", text: "Events")
                    OnbChip(icon: "airplane", text: "Trips")
                    OnbChip(icon: "sparkles", text: "AI", goldStyle: true)
                }
                .padding(.top, 20)

                Spacer()

                VStack(spacing: 6) {
                    OnbPrimaryButton(title: "Get Started", action: onNext)
                    Text("7-day free trial of Cashew Premium included")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private var logoStage: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(OnbTheme.primarySoft.opacity(0.35))
                .frame(width: 200, height: 200)
                .blur(radius: 24)

            // Background plate
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))

            // Pulse rings
            OnbPulseRing()
                .frame(width: 200, height: 200)
            OnbPulseRing(delay: 1.2)
                .frame(width: 200, height: 200)

            // Logo
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 88, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 0.70, green: 0.86, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 8)

            // Sparkles
            OnbSparkle(size: 14)
                .offset(x: -70, y: -78)
            OnbSparkle(size: 10)
                .offset(x: 78, y: -56)
            OnbSparkle(size: 10)
                .offset(x: -84, y: 58)
            OnbSparkle(size: 14)
                .offset(x: 60, y: 76)
        }
    }
}
