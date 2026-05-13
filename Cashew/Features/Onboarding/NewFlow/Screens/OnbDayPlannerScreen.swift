import SwiftUI

struct OnbDayPlannerScreen: View {

    let onNext: () -> Void
    var onSkip: (() -> Void)?
    var onBack: (() -> Void)?
    let step: Int
    let total: Int

    var body: some View {
        ZStack {
            OnbTheme.pageBackground.ignoresSafeArea()

            ZStack {
                OnbOrb(tint: .blue)
                OnbOrb(tint: .purple)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbSkipBar(onSkip: onSkip)

                Spacer(minLength: 0)

                plannerCard
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Earn XP · Build streaks · Level up")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.bottom, 20)

                OnbTextBlock(
                    eyebrow: { OnbEyebrow(text: "Day Planner") },
                    title: "A schedule that\nroots for you.",
                    subtitle: "Plan tasks, build routines, and earn XP for every win. Climb 7 levels from *Starter* to *Expert*."
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

    private var plannerCard: some View {
        OnbPreviewCard(
            borderColor: OnbTheme.primarySoft.opacity(0.32),
            padding: 18,
            background: {
                LinearGradient(
                    colors: [OnbTheme.primary.opacity(0.32), OnbTheme.secondary.opacity(0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TUESDAY")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .tracking(0.4)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Today's Mission")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        streakChip
                    }

                    HStack(spacing: 14) {
                        progressRing
                        VStack(alignment: .leading, spacing: 6) {
                            Text("4 of 6 done")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                            HStack(spacing: 8) {
                                statTile(icon: "bolt.fill", label: "+180", sub: "XP today")
                                statTile(icon: "trophy.fill", label: "Lv 4", sub: "Voyager")
                            }
                        }
                    }

                    VStack(spacing: 6) {
                        taskRow(text: "Morning workout", tag: "HEALTH", done: true)
                        taskRow(text: "Review design system", tag: "WORK", done: true)
                        taskRow(text: "Book Lisbon flights", tag: "TRIP", done: false, highlight: true)
                    }
                }
            }
        )
    }

    private var streakChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(OnbTheme.tertiarySoft)
            Text("12 day streak")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(OnbTheme.tertiarySoft.opacity(0.22))
        .clipShape(Capsule())
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 6)
                .frame(width: 72, height: 72)
            Circle()
                .trim(from: 0, to: 0.65)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(-90))
            Text("65%")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func statTile(icon: String, label: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(OnbTheme.tertiarySoft)
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(sub)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func taskRow(text: String, tag: String, done: Bool, highlight: Bool = false) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(done
                        ? AnyShapeStyle(LinearGradient(
                            colors: [OnbTheme.positive, OnbTheme.positiveBright],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.clear))
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(done ? Color.clear : Color.white.opacity(0.35), lineWidth: 1.5)
                    )
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                }
            }

            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(done ? 0.55 : 1.0))
                .strikethrough(done, color: .white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(tag)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(highlight ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(highlight ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
        )
    }
}
