import SwiftUI

struct OnbAIMoreScreen: View {

    let onNext: () -> Void
    var onSkip: (() -> Void)?
    var onBack: (() -> Void)?
    let step: Int
    let total: Int

    var body: some View {
        ZStack {
            OnbTheme.pageBackground.ignoresSafeArea()

            ZStack {
                OnbOrb(tint: .gold)
                OnbOrb(tint: .pink)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbSkipBar(onSkip: onSkip)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    packingCard
                    journalCard
                }
                .frame(maxWidth: 320)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

                OnbTextBlock(
                    eyebrow: { OnbEyebrow(text: "AI · Cashew Premium", icon: "sparkles", goldStyle: true) },
                    title: "Pack smarter.\nRemember more.",
                    subtitle: "AI builds your packing list and writes a journal of your trip when you're back home — keepsake-ready."
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

    private var packingCard: some View {
        OnbPreviewCard(
            borderColor: OnbTheme.premiumGold.opacity(0.28),
            padding: 14,
            background: {
                LinearGradient(
                    colors: [OnbTheme.warning.opacity(0.18), OnbTheme.secondary.opacity(0.14)],
                    startPoint: .top, endPoint: .bottom
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(OnbTheme.warning.opacity(0.32))
                                .frame(width: 28, height: 28)
                            Image(systemName: "bag.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.77, blue: 0.56))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("AI Packing List")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Carry-on · Warm weather · 9 days")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer()
                        OnbLockBadge(label: "Pro")
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 5),
                                        GridItem(.flexible(), spacing: 5)], spacing: 5) {
                        packItem(text: "3 linen shirts", done: true)
                        packItem(text: "Walking shoes", done: true)
                        packItem(text: "Adapter (EU)", done: false)
                        packItem(text: "Sunscreen SPF 50", done: false)
                        packItem(text: "Light rain jacket", done: false)
                        packItem(text: "Power bank", done: false)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color(red: 1.0, green: 0.77, blue: 0.56))
                        Text("24 items, 6 categories — generated in seconds")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        )
    }

    private var journalCard: some View {
        OnbPreviewCard(
            borderColor: OnbTheme.tertiarySoft.opacity(0.28),
            padding: 14,
            background: {
                LinearGradient(
                    colors: [OnbTheme.tertiarySoft.opacity(0.18), OnbTheme.secondary.opacity(0.14)],
                    startPoint: .top, endPoint: .bottom
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(OnbTheme.tertiarySoft.opacity(0.32))
                                .frame(width: 28, height: 28)
                            Image(systemName: "book.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.71, blue: 0.89))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("AI Trip Journal")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Warm · Reflective tone")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer()
                        OnbLockBadge(label: "Pro")
                    }

                    Text("\"Lisbon arrived softly — pastel tiles, the slow rumble of Tram 28, and an evening of Fado that felt like the city was singing for us. Day three blurred into trams and tiles…\"")
                        .font(.system(size: 11, design: .rounded).italic())
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(2)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 6) {
                        OnbChip(icon: "sparkles", text: "Warm")
                        OnbChip(icon: "wand.and.stars", text: "Adventurous")
                        OnbChip(icon: "smiley.fill", text: "Witty")
                    }
                    .scaleEffect(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        )
    }

    private func packItem(text: String, done: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(done ? OnbTheme.positive : Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(done ? Color.clear : Color.white.opacity(0.40), lineWidth: 1.5)
                    )
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            Text(text)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.white.opacity(done ? 0.6 : 1.0))
                .strikethrough(done, color: .white.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
