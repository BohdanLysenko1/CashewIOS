import SwiftUI

struct OnbTripsScreen: View {

    let onNext: () -> Void
    var onSkip: (() -> Void)?
    var onBack: (() -> Void)?
    let step: Int
    let total: Int

    var body: some View {
        ZStack {
            OnbTheme.pageBackground.ignoresSafeArea()

            ZStack {
                OnbOrb(tint: .purple)
                OnbOrb(tint: .cyan)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbSkipBar(onSkip: onSkip)

                Spacer(minLength: 0)

                tripContent
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                OnbTextBlock(
                    eyebrow: { OnbEyebrow(text: "Trips") },
                    title: "Every adventure,\nhandled.",
                    subtitle: "Budget, packing, itinerary, weather, and accommodation — all in one place. Plan together with friends."
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 16)

                VStack(spacing: 10) {
                    OnbPrimaryButton(title: "Next", action: onNext)
                    OnbBottomNav(step: step, total: total, onBack: onBack)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private var tripContent: some View {
        VStack(spacing: 10) {
            tripHero

            HStack(spacing: 8) {
                featTile(icon: "dollarsign.circle.fill", label: "Budget",   color: OnbTheme.positive,    pct: 0.6)
                featTile(icon: "bag.fill",                label: "Packing",  color: OnbTheme.warning,     pct: 0.8)
                featTile(icon: "map.fill",                label: "Itinerary",color: OnbTheme.primary,     pct: 0.5)
                featTile(icon: "person.2.fill",           label: "Shared",   color: OnbTheme.tertiarySoft, sub: "2 ppl")
            }

            HStack(spacing: 10) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.56, green: 0.72, blue: 1.0))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lisbon · Apr 3")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("72° · Sunny · Light breeze")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Text("72°")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private var tripHero: some View {
        OnbPreviewCard(
            borderColor: Color.white.opacity(0.18),
            padding: 18,
            background: {
                LinearGradient(
                    colors: [OnbTheme.secondary, OnbTheme.primary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            },
            content: {
                ZStack(alignment: .topTrailing) {
                    // Decorative circle
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 140, height: 140)
                        .offset(x: 50, y: -60)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "airplane")
                                .font(.system(size: 11, weight: .heavy))
                            Text("UPCOMING TRIP · 14 DAYS")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 8)

                        Text("Lisbon, Portugal")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Apr 3 – Apr 12 · 9 days")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 14)

                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Readiness")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.75))
                                Text("72%")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.22))
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: geo.size.width * 0.72)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        )
    }

    private func featTile(icon: String, label: String, color: Color, pct: Double? = nil, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.20))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            if let pct {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule().fill(color).frame(width: geo.size.width * pct)
                    }
                }
                .frame(height: 3)
            } else if let sub {
                Text(sub)
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
