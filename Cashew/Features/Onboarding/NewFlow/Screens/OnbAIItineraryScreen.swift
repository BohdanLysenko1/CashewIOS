import SwiftUI

struct OnbAIItineraryScreen: View {

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
                OnbOrb(tint: .gold)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbSkipBar(onSkip: onSkip)

                Spacer(minLength: 0)

                itineraryCard
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)

                OnbTextBlock(
                    eyebrow: { OnbEyebrow(text: "AI · Cashew Premium", icon: "sparkles", goldStyle: true) },
                    title: "Itineraries written\njust for you.",
                    subtitle: "Tell Cashew your destination and budget. Get a day-by-day plan in seconds — saved straight to your trip."
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

    private var itineraryCard: some View {
        OnbPreviewCard(
            borderColor: OnbTheme.primarySoft.opacity(0.30),
            padding: 16,
            background: {
                LinearGradient(
                    colors: [OnbTheme.secondary.opacity(0.20), OnbTheme.primary.opacity(0.16)],
                    startPoint: .top, endPoint: .bottom
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(OnbTheme.premiumGradient)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(OnbTheme.inkOnGold)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI Itinerary")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Lisbon · 9 days · $1,800 budget")
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                        }
                        Spacer()
                        OnbLockBadge()
                    }
                    .padding(.bottom, 12)

                    activity(time: "Day 1 · 10am", title: "Belém Tower & monastery", cost: "€12", tag: "Culture", highlight: false)
                    activity(time: "Day 1 · 7pm",  title: "Fado dinner in Alfama",   cost: "€45", tag: "Food",    highlight: false)
                    activity(time: "Day 2 · 9am",  title: "Day trip to Sintra",      cost: "€60", tag: "Adventure", highlight: true)

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(OnbTheme.premiumGold)
                        Text("Generated in 4 seconds. Tailored to your budget.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(OnbTheme.premiumGold.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(OnbTheme.premiumGold.opacity(0.28), lineWidth: 1)
                    )
                    .padding(.top, 8)
                }
            }
        )
    }

    private func activity(time: String, title: String, cost: String, tag: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(time)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(Color(red: 0.77, green: 0.79, blue: 1.0))
                Spacer()
                Text(cost)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(tag)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlight ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(highlight
                    ? OnbTheme.primarySoft.opacity(0.40)
                    : Color.white.opacity(0.08),
                    lineWidth: 1)
        )
        .padding(.bottom, 6)
    }
}
