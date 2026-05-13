import SwiftUI

struct OnbPaywallScreen: View {

    let onSubscribe: () -> Void
    let onMaybeLater: () -> Void
    var onBack: (() -> Void)?
    let step: Int
    let total: Int

    @State private var plan: Plan = .annual

    enum Plan { case annual, monthly }

    private let trialDays = 7
    private let annualPrice = 47.88
    private let monthlyPrice = 5.99

    private var annualMonthly: String { String(format: "%.2f", annualPrice / 12) }
    private var annualDaily: String   { String(format: "%.2f", annualPrice / 365) }
    private var savings: Int          { Int((1.0 - (annualPrice / 12) / monthlyPrice) * 100) }
    private var monthlyPriceStr: String { String(format: "%.2f", monthlyPrice) }
    private var annualPriceStr: String  { String(format: "%.2f", annualPrice) }

    var body: some View {
        ZStack {
            OnbTheme.paywallBackground.ignoresSafeArea()

            ZStack {
                OnbOrb(tint: .gold).opacity(0.5)
                OnbOrb(tint: .purple)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbSkipBar(onSkip: onMaybeLater)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        crownBurst
                            .padding(.top, 8)

                        VStack(spacing: 8) {
                            VStack(spacing: 0) {
                                Text("Try Cashew Premium")
                                    .foregroundStyle(.white)
                                Text("free for \(trialDays) days.")
                                    .foregroundStyle(OnbTheme.premiumGradient)
                            }
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)

                            Text("Unlock every AI feature. Cancel anytime — no charge during trial.")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white.opacity(0.68))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        VStack(spacing: 0) {
                            benefit(icon: "sparkles", title: "AI Itinerary Builder", desc: "Day-by-day plans tailored to your budget")
                            benefit(icon: "bag.fill", title: "AI Packing List",      desc: "Smart lists for any climate, length, vibe")
                            benefit(icon: "book.fill", title: "AI Trip Journal",     desc: "Beautiful summaries of every adventure")
                            benefit(icon: "bolt.fill", title: "Priority sync & support", desc: "Faster cloud + first-class help")
                            benefit(icon: "heart.fill", title: "Future AI features", desc: "Everything new, always included", divider: false)
                        }

                        VStack(spacing: 10) {
                            planCard(
                                plan: .annual,
                                title: "Annual",
                                badge: savings > 0 ? "SAVE \(savings)%" : nil,
                                price: "$\(annualMonthly)",
                                period: "/ month, billed yearly",
                                sub: "$\(annualPriceStr)/yr · just $\(annualDaily)/day"
                            )
                            planCard(
                                plan: .monthly,
                                title: "Monthly",
                                badge: nil,
                                price: "$\(monthlyPriceStr)",
                                period: "/ month",
                                sub: "Billed monthly · cancel anytime"
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
                }

                VStack(spacing: 8) {
                    OnbPrimaryButton(title: "Start \(trialDays)-day free trial",
                                     variant: .gold,
                                     action: onSubscribe)

                    Text(legalLine)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    OnbGhostButton(title: "Continue with the free version", action: onMaybeLater)
                    OnbBottomNav(step: step, total: total, onBack: onBack)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 8)
            }
        }
    }

    private var legalLine: String {
        let priceLine = plan == .annual
            ? "Then $\(annualPriceStr)/yr ($\(annualMonthly)/mo)"
            : "Then $\(monthlyPriceStr)/mo"
        return "\(priceLine) · Cancel anytime in Settings · 30-day money back"
    }

    private var crownBurst: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(OnbTheme.premiumGradient)
                .frame(width: 78, height: 78)
                .shadow(color: OnbTheme.premiumAmber.opacity(0.45), radius: 20, x: 0, y: 12)

            Image(systemName: "crown.fill")
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(OnbTheme.inkOnGold)

            OnbSparkle(size: 14).offset(x: -42, y: -42)
            OnbSparkle(size: 12).offset(x: 44, y: -38)
            OnbSparkle(size: 10).offset(x: 38, y: 42)
        }
    }

    private func benefit(icon: String, title: String, desc: String, divider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(OnbTheme.premiumGold.opacity(0.18))
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(OnbTheme.premiumGold.opacity(0.30), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(OnbTheme.premiumGold)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(desc)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(OnbTheme.premiumGold)
            }
            .padding(.vertical, 10)

            if divider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }
        }
    }

    private func planCard(plan: Plan, title: String, badge: String?, price: String, period: String, sub: String) -> some View {
        let selected = plan == self.plan
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { self.plan = plan }
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.30), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        if selected {
                            Circle().fill(OnbTheme.premiumGold).frame(width: 20, height: 20)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(OnbTheme.inkOnGold)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(sub)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(price)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(period)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(selected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [OnbTheme.premiumGold.opacity(0.18), OnbTheme.premiumAmber.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.white.opacity(0.04)))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(selected ? OnbTheme.premiumGold : Color.white.opacity(0.10),
                                lineWidth: 2)
                )

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(OnbTheme.inkOnGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(OnbTheme.premiumGradient)
                        .clipShape(Capsule())
                        .offset(x: -14, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
