import SwiftUI

struct OnbCalendarScreen: View {

    let onNext: () -> Void
    var onSkip: (() -> Void)?
    var onBack: (() -> Void)?
    let step: Int
    let total: Int

    private static let events: [Int: [Color]] = [
        3:  [OnbTheme.primary],
        7:  [OnbTheme.secondary, OnbTheme.tertiarySoft],
        10: [OnbTheme.primary],
        14: [OnbTheme.secondary],
        15: [OnbTheme.secondary],
        16: [OnbTheme.secondary],
        17: [OnbTheme.secondary],
        19: [OnbTheme.primary, OnbTheme.tertiarySoft],
        21: [OnbTheme.tertiarySoft],
        22: [OnbTheme.tertiarySoft, OnbTheme.primary],
        27: [OnbTheme.primary],
        28: [OnbTheme.secondary]
    ]

    var body: some View {
        ZStack {
            OnbTheme.pageBackground.ignoresSafeArea()

            ZStack {
                OnbOrb(tint: .purple)
                OnbOrb(tint: .blue)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbSkipBar(onSkip: onSkip)

                Spacer(minLength: 0)

                calendarCard
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                OnbTextBlock(
                    eyebrow: { OnbEyebrow(text: "Calendar") },
                    title: "The big picture,\nall in one view.",
                    subtitle: "Trips, events, and tasks on a single calendar. Filter by category and tap any day for the details."
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

    private var calendarCard: some View {
        OnbPreviewCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("March 2026")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 6) {
                        filterDot(color: OnbTheme.primary, label: "Tasks")
                        filterDot(color: OnbTheme.secondary, label: "Trips")
                        filterDot(color: OnbTheme.tertiarySoft, label: "Events")
                    }
                }

                calendarGrid

                VStack(alignment: .leading, spacing: 6) {
                    Text("SAT · MAR 22")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 8) {
                        Circle().fill(OnbTheme.tertiarySoft).frame(width: 6, height: 6)
                        Text("Maya's birthday")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    HStack(spacing: 8) {
                        Circle().fill(OnbTheme.primary).frame(width: 6, height: 6)
                        Text("Pack for Lisbon")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
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
    }

    private func filterDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.20))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.33), lineWidth: 1))
    }

    private var calendarGrid: some View {
        let days = ["S", "M", "T", "W", "T", "F", "S"]
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<7) { i in
                    Text(days[i])
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }
            // March 1, 2026 is a Sunday → 0 leading blanks. We render 35 cells.
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = row * 7 + col + 1
                        gridCell(day: day <= 31 ? day : nil)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func gridCell(day: Int?) -> some View {
        let isToday = (day == 22)
        let dots = day.flatMap { Self.events[$0] } ?? []

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isToday ? Color.white : Color.clear)

            VStack(spacing: 2) {
                if let day {
                    Text("\(day)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(isToday ? OnbTheme.darkInk : .white)
                }
                if !dots.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(0..<min(dots.count, 3), id: \.self) { i in
                            Circle().fill(dots[i]).frame(width: 3, height: 3)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
