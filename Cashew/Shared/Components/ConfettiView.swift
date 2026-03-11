import SwiftUI

// MARK: - Particle Data

private struct ParticleData: Identifiable {
    let id = UUID()
    let color: Color
    let targetX: CGFloat
    let targetY: CGFloat
    let rotation: Double
    let isRect: Bool
    let size: CGFloat
}

// MARK: - Single Particle

private struct Particle: View {

    let data: ParticleData
    @State private var x: CGFloat = 0
    @State private var y: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0.1
    @State private var spin: Double = 0

    var body: some View {
        Group {
            if data.isRect {
                RoundedRectangle(cornerRadius: 2)
                    .fill(data.color)
                    .frame(width: data.size * 0.7, height: data.size)
            } else {
                Circle()
                    .fill(data.color)
                    .frame(width: data.size, height: data.size)
            }
        }
        .rotationEffect(.degrees(spin))
        .scaleEffect(scale)
        .offset(x: x, y: y)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: AppTheme.confettiDuration)) {
                x = data.targetX
                y = data.targetY
                scale = 1.0
                spin = data.rotation
            }
            withAnimation(.easeIn(duration: AppTheme.confettiFadeDuration).delay(AppTheme.confettiFadeDelay)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Confetti Burst

struct ConfettiView: View {

    @State private var particles: [ParticleData] = []

    private static let colors: [Color] = [
        .yellow, .green, .blue, .pink, .orange, .purple, .red, .mint, .cyan
    ]

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Particle(data: p)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            particles = (0..<18).map { _ in
                ParticleData(
                    color: Self.colors.randomElement() ?? .yellow,
                    targetX: CGFloat.random(in: -72...72),
                    targetY: CGFloat.random(in: -90 ... -14),
                    rotation: Double.random(in: 0...360),
                    isRect: Bool.random(),
                    size: CGFloat.random(in: 6...11)
                )
            }
        }
    }
}
