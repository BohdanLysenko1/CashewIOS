import SwiftUI

struct CompletionView: View {

    let onFinish: () -> Void

    @State private var iconScale: CGFloat = 0.2
    @State private var iconOpacity: Double = 0
    @State private var textOffset: CGFloat = 36
    @State private var textOpacity: Double = 0
    @State private var buttonScale: CGFloat = 0.85
    @State private var buttonOpacity: Double = 0
    @State private var showConfetti = false

    // Floating orbs — same feel as WelcomeScreen
    @State private var orbOpacity: Double = 0
    @State private var orb1Float: CGSize = .zero
    @State private var orb2Float: CGSize = .zero

    var body: some View {
        ZStack {
            // Background — matches welcome screen
            AppTheme.onboardingBackground
                .ignoresSafeArea()

            // Floating orbs
            Circle()
                .fill(Color.yellow.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: -80 + orb1Float.width, y: -120 + orb1Float.height)
                .opacity(orbOpacity)

            Circle()
                .fill(Color.orange.opacity(0.14))
                .frame(width: 170, height: 170)
                .blur(radius: 40)
                .offset(x: 90 + orb2Float.width, y: 60 + orb2Float.height)
                .opacity(orbOpacity)

            // Confetti — three bursts across the screen
            if showConfetti {
                GeometryReader { geo in
                    ConfettiView()
                        .position(x: geo.size.width * 0.22, y: geo.size.height * 0.38)
                    ConfettiView()
                        .position(x: geo.size.width * 0.50, y: geo.size.height * 0.28)
                    ConfettiView()
                        .position(x: geo.size.width * 0.78, y: geo.size.height * 0.38)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Icon with outer glow rings
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.12))
                        .frame(width: 180, height: 180)
                        .blur(radius: 20)

                    Circle()
                        .fill(Color.yellow.opacity(0.14))
                        .frame(width: 148, height: 148)

                    Circle()
                        .fill(Color.orange.opacity(0.10))
                        .frame(width: 122, height: 122)

                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 68))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                Spacer().frame(height: 40)

                VStack(spacing: 12) {
                    Text("You're All Set!")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("You're ready to plan your days and adventures.\nLet's get started.")
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)

                Spacer()

                Button(action: onFinish) {
                    Text("Let's Go!")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [.yellow, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.orange.opacity(0.45), radius: 22, y: 5)
                }
                .padding(.horizontal, 32)
                .scaleEffect(buttonScale)
                .opacity(buttonOpacity)

                Spacer().frame(height: 56)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { animateIn() }
        .interactiveDismissDisabled()
    }

    private func animateIn() {
        // Orbs fade in
        withAnimation(.easeOut(duration: 1.0)) {
            orbOpacity = 1
        }

        // Icon pop in
        withAnimation(.spring(response: 0.62, dampingFraction: 0.52).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1
        }

        // Text slide up
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.44)) {
            textOffset = 0
            textOpacity = 1
        }

        // Button bounce in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.68).delay(0.72)) {
            buttonScale = 1.0
            buttonOpacity = 1
        }

        // Confetti burst — slight delay for impact
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            showConfetti = true
        }

        // Orb continuous float
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                orb1Float = CGSize(width: 20, height: -18)
            }
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
                orb2Float = CGSize(width: -16, height: 14)
            }
        }
    }
}
