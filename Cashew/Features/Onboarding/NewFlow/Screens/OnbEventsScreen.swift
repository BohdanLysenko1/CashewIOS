import SwiftUI

struct OnbEventsScreen: View {

    let onNext: () -> Void
    var onSkip: (() -> Void)?
    var onBack: (() -> Void)?
    let step: Int
    let total: Int

    var body: some View {
        ZStack {
            OnbTheme.pageBackground.ignoresSafeArea()

            ZStack {
                OnbOrb(tint: .pink)
                OnbOrb(tint: .purple)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbSkipBar(onSkip: onSkip)

                Spacer(minLength: 0)

                eventStack
                    .frame(height: 280)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                OnbTextBlock(
                    eyebrow: { OnbEyebrow(text: "Events") },
                    title: "Track every\nmoment that matters.",
                    subtitle: "Priorities, reminders, costs, recurring schedules — and link any event to a trip."
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

    private var eventStack: some View {
        ZStack {
            eventCard(
                date: "FRI · MAR 14",
                title: "Team offsite",
                location: "Brooklyn",
                priority: .medium,
                color: OnbTheme.secondary,
                cost: nil,
                repeating: false,
                linked: nil
            )
            .padding(.horizontal, 18)
            .rotationEffect(.degrees(-3))
            .opacity(0.55)
            .offset(y: -90)

            eventCard(
                date: "SAT · MAR 22",
                title: "Maya's birthday",
                location: "Greenpoint, NY",
                priority: .high,
                color: OnbTheme.tertiarySoft,
                cost: "$120",
                repeating: true,
                linked: nil
            )
            .padding(.horizontal, 8)
            .rotationEffect(.degrees(2))
            .opacity(0.85)
            .offset(y: -10)

            eventCard(
                date: "THU · APR 03",
                title: "Flight to Lisbon",
                location: "JFK Terminal 4 · 9:40 PM",
                priority: .high,
                color: OnbTheme.primary,
                cost: "$420",
                repeating: false,
                linked: "Lisbon Trip"
            )
            .offset(y: 70)
        }
    }

    private enum Priority { case high, medium }

    private func eventCard(
        date: String,
        title: String,
        location: String,
        priority: Priority,
        color: Color,
        cost: String?,
        repeating: Bool,
        linked: String?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(date)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(color)
                    Spacer()
                    Text(priority == .high ? "HIGH" : "MED")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(priority == .high
                            ? Color(red: 0.85, green: 0.23, blue: 0.31)
                            : Color(red: 0.90, green: 0.55, blue: 0.14))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priority == .high
                            ? Color(red: 1.0, green: 0.91, blue: 0.92)
                            : Color(red: 1.0, green: 0.96, blue: 0.90))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.17, green: 0.18, blue: 0.19))

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                    Text(location)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.40, green: 0.41, blue: 0.42))

                if cost != nil || repeating || linked != nil {
                    HStack(spacing: 6) {
                        if let cost {
                            OnbMiniPill(icon: "dollarsign.circle.fill", text: cost)
                        }
                        if repeating {
                            OnbMiniPill(icon: "arrow.triangle.2.circlepath", text: "Yearly")
                        }
                        if let linked {
                            OnbMiniPill(icon: "airplane", text: linked, accent: OnbTheme.primary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 12)
    }
}
