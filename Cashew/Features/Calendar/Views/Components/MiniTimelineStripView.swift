import SwiftUI

// MARK: - MiniTimelineStripView

/// A compact (~56 pt) horizontal timeline showing event and task blocks for a single day.
///
/// ## Block sources
/// Both timed events and tasks with startTime+endTime render as proportional blocks.
/// Tasks with only a startTime (no endTime) render as thin tick marks.
///
/// ## Overlap strategy: 2-lane stacking
/// Items are assigned to one of two sub-lanes within the strip track.
/// Two lanes handle >95% of real-world calendar density. Triple-overlap z-stacks on lane 0.
struct MiniTimelineStripView: View {

    // MARK: - Input

    /// Non-all-day timed events for the day (caller should pre-filter).
    let events: [Event]
    /// All tasks for the day; internal filtering splits into blocks vs ticks.
    let tasks: [DailyTask]
    let selectedDate: Date

    /// Minimum displayed time range. Expands automatically to fit all events/tasks.
    var startHour: Int = 8
    var endHour:   Int = 21

    // MARK: - Effective range (auto-expanded to fit data)

    private var effectiveStartHour: Int {
        let cal = Calendar.current
        var minH = CGFloat(startHour)
        for event in events {
            let h = CGFloat(cal.component(.hour, from: event.date))
                  + CGFloat(cal.component(.minute, from: event.date)) / 60
            if h < minH { minH = h }
        }
        for task in tasks {
            if let st = task.startTime {
                let h = CGFloat(cal.component(.hour, from: st))
                      + CGFloat(cal.component(.minute, from: st)) / 60
                if h < minH { minH = h }
            }
        }
        return max(0, Int(floor(minH)))
    }

    private var effectiveEndHour: Int {
        let cal = Calendar.current
        var maxH = CGFloat(endHour)
        for event in events {
            let end = event.endDate ?? event.date.addingTimeInterval(3600)
            let h = CGFloat(cal.component(.hour, from: end))
                  + CGFloat(cal.component(.minute, from: end)) / 60
            if h > maxH { maxH = h }
        }
        for task in tasks {
            if let et = task.endTime {
                let h = CGFloat(cal.component(.hour, from: et))
                      + CGFloat(cal.component(.minute, from: et)) / 60
                if h > maxH { maxH = h }
            } else if let st = task.startTime {
                let h = CGFloat(cal.component(.hour, from: st))
                      + CGFloat(cal.component(.minute, from: st)) / 60
                if h > maxH { maxH = h }
            }
        }
        return min(24, Int(ceil(maxH)))
    }

    // MARK: - State

    @State private var tooltip: TooltipState? = nil

    // MARK: - Layout constants

    private let trackH:  CGFloat = 28   // canvas height for the strip
    private let labelH:  CGFloat = 14
    private let padH:    CGFloat = 12

    // MARK: - Body

    var body: some View {
        let blocks    = layoutBlocks()
        let tickTasks = tasks.filter { $0.startTime != nil && $0.endTime == nil }
        let isToday   = Calendar.current.isDateInToday(selectedDate)

        VStack(spacing: 0) {

            // ── Interactive strip ───────────────────────────────────────
            GeometryReader { geo in
                let w = geo.size.width

                Canvas { ctx, size in
                    let trackY: CGFloat = 8   // top of 14 pt background track

                    // 1. Background track
                    ctx.fill(
                        Path(roundedRect: CGRect(x: 0, y: trackY, width: size.width, height: 14),
                             cornerRadius: 5),
                        with: .color(AppTheme.surfaceContainerHigh)
                    )

                    // 2. Duration blocks (events + tasks with start+end) — 2-lane layout
                    for b in blocks {
                        let x  = b.startFrac * size.width
                        let bw = max(8, (b.endFrac - b.startFrac) * size.width)
                        // Lane 0 → top half; Lane 1 → bottom half of the 14pt track
                        let y: CGFloat = b.lane == 0 ? trackY + 1 : trackY + 8
                        let opacity: CGFloat = b.isTask ? 0.70 : 0.90
                        ctx.fill(
                            Path(roundedRect: CGRect(x: x, y: y, width: bw, height: 5),
                                 cornerRadius: 2.5),
                            with: .color(b.color.opacity(opacity))
                        )
                    }

                    // 3. Tick marks — tasks with only startTime (no duration)
                    for task in tickTasks {
                        guard let st = task.startTime else { continue }
                        let x = clamp01(frac(for: st)) * size.width
                        ctx.fill(
                            Path(roundedRect: CGRect(x: x - 1.5, y: trackY + 1, width: 3, height: 12),
                                 cornerRadius: 1.5),
                            with: .color(task.category.color.opacity(0.75))
                        )
                    }

                    // 4. "Now" indicator — dot + vertical line (today only)
                    if isToday {
                        let cal  = Calendar.current
                        let nowH = CGFloat(cal.component(.hour,   from: Date()))
                                 + CGFloat(cal.component(.minute, from: Date())) / 60
                        let f    = frac(hour: nowH)
                        if f >= 0, f <= 1 {
                            let x = f * size.width
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x - 4, y: trackY - 4, width: 8, height: 8)),
                                with: .color(.red)
                            )
                            ctx.fill(
                                Path(roundedRect: CGRect(x: x - 1, y: trackY - 4, width: 2, height: 22),
                                     cornerRadius: 1),
                                with: .color(.red.opacity(0.6))
                            )
                        }
                    }

                    // 5. Drag scrubber — vertical hairline + thumb (only while dragging)
                    if let tip = tooltip {
                        let x = tip.fraction * size.width
                        // Hairline spanning the full track height
                        ctx.fill(
                            Path(roundedRect: CGRect(x: x - 1, y: trackY - 5, width: 2, height: 24),
                                 cornerRadius: 1),
                            with: .color(Color.primary.opacity(0.55))
                        )
                        // Outer ring
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - 7, y: trackY + 3, width: 14, height: 8)),
                            with: .color(Color.primary.opacity(0.12))
                        )
                        // Inner dot
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - 4, y: trackY + 5, width: 8, height: 4)),
                            with: .color(Color.primary.opacity(0.75))
                        )
                    }
                }
                .frame(height: trackH)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let f = max(0, min(1, val.location.x / w))
                            updateTooltip(fraction: f, blocks: blocks)
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.15)) { tooltip = nil }
                        }
                )
            }
            .frame(height: trackH)

            // ── Time anchor labels ──────────────────────────────────────
            GeometryReader { geo in
                ForEach(Array(anchorLabels.enumerated()), id: \.offset) { _, anchor in
                    Text(anchor.label)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .frame(width: 32, alignment: .center)
                        .offset(x: anchor.fraction * geo.size.width - 16, y: 2)
                }
            }
            .frame(height: labelH)
        }
        .padding(.horizontal, padH)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        // Tooltip — overlaid AFTER clipShape so it is not clipped
        .overlay(alignment: .topLeading) {
            if let tip = tooltip {
                GeometryReader { geo in
                    let trackWidth = geo.size.width - padH * 2
                    let centerX    = padH + tip.fraction * trackWidth
                    let bubbleW:   CGFloat = 130
                    let clampedX   = min(max(padH, centerX - bubbleW / 2),
                                        geo.size.width - padH - bubbleW)
                    TimelineTooltipBubble(time: tip.time, title: tip.itemTitle)
                        .frame(width: bubbleW)
                        .offset(x: clampedX, y: -46)
                }
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Anchor Labels

    /// Fixed labels: start hour, 12p, 5p, and end hour.
    private var anchorLabels: [(label: String, fraction: CGFloat)] {
        var seen = Set<Int>()
        return [effectiveStartHour, 12, 17, effectiveEndHour]
            .filter { $0 >= effectiveStartHour && $0 <= effectiveEndHour }
            .sorted()
            .compactMap { h in
                guard seen.insert(h).inserted else { return nil }
                let label = h == 0 ? "12am" : h < 12 ? "\(h)am" : h == 12 ? "12pm" : "\(h - 12)pm"
                return (label, frac(hour: CGFloat(h)))
            }
    }

    // MARK: - Layout (2-lane stacking)

    private struct LaidOutBlock {
        let title:     String
        let lane:      Int        // 0 = top, 1 = bottom
        let startFrac: CGFloat
        let endFrac:   CGFloat
        let color:     Color
        let isTask:    Bool
    }

    private func layoutBlocks() -> [LaidOutBlock] {
        struct RawItem {
            let title:     String
            let startDate: Date
            let endDate:   Date
            let color:     Color
            let isTask:    Bool
        }

        var items: [RawItem] = []

        // Events → always have a block; fallback endDate = start + ~1 hr if missing
        for event in events {
            let end = event.endDate ?? event.date.addingTimeInterval(3600)
            items.append(RawItem(title: event.title,
                                 startDate: event.date,
                                 endDate: end,
                                 color: event.category.color,
                                 isTask: false))
        }

        // Tasks with both startTime and endTime → show as blocks
        for task in tasks {
            guard let st = task.startTime, let et = task.endTime else { continue }
            items.append(RawItem(title: task.title,
                                 startDate: st,
                                 endDate: et,
                                 color: task.category.color,
                                 isTask: true))
        }

        let sorted = items.sorted { $0.startDate < $1.startDate }
        var laneEnd: [CGFloat] = [-.infinity, -.infinity]
        var result:  [LaidOutBlock] = []

        for item in sorted {
            let sf     = clamp01(frac(for: item.startDate))
            let rawEF  = frac(for: item.endDate)
            let ef     = clamp01(max(sf + 0.015, rawEF))

            let lane: Int
            if      sf >= laneEnd[0] { lane = 0 }
            else if sf >= laneEnd[1] { lane = 1 }
            else                     { lane = 0 }

            laneEnd[lane] = ef
            result.append(LaidOutBlock(title: item.title, lane: lane,
                                       startFrac: sf, endFrac: ef,
                                       color: item.color, isTask: item.isTask))
        }
        return result
    }

    // MARK: - Tooltip

    private struct TooltipState: Equatable {
        let fraction:  CGFloat
        let time:      String
        let itemTitle: String?
    }

    private func updateTooltip(fraction: CGFloat, blocks: [LaidOutBlock]) {
        let totalH = CGFloat(effectiveEndHour - effectiveStartHour)
        let rawH   = CGFloat(effectiveStartHour) + fraction * totalH
        let h      = Int(rawH)
        let m      = Int((rawH - CGFloat(h)) * 60)
        let ap     = h < 12 ? "AM" : "PM"
        let dh     = h == 0 ? 12 : h > 12 ? h - 12 : h
        let timeStr = String(format: "%d:%02d %@", dh, m, ap)

        // Show the title of whichever block the scrubber is currently inside.
        // Among overlapping blocks prefer lane 0, then the one whose centre is closest.
        let hit = blocks
            .filter { fraction >= $0.startFrac && fraction <= $0.endFrac }
            .min {
                if $0.lane != $1.lane { return $0.lane < $1.lane }
                let c0 = abs(($0.startFrac + $0.endFrac) / 2 - fraction)
                let c1 = abs(($1.startFrac + $1.endFrac) / 2 - fraction)
                return c0 < c1
            }

        let snapTitle = hit?.title

        if let title = snapTitle, tooltip?.itemTitle != title {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if snapTitle == nil && tooltip?.itemTitle != nil {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        let newState = TooltipState(fraction: fraction, time: timeStr, itemTitle: snapTitle)
        if tooltip != newState { tooltip = newState }
    }

    // MARK: - Fraction helpers

    private func frac(for date: Date) -> CGFloat {
        let cal = Calendar.current
        let h   = CGFloat(cal.component(.hour,   from: date))
                + CGFloat(cal.component(.minute, from: date)) / 60
        return frac(hour: h)
    }

    private func frac(hour: CGFloat) -> CGFloat {
        let span = CGFloat(effectiveEndHour - effectiveStartHour)
        guard span > 0 else { return 0 }
        return (hour - CGFloat(effectiveStartHour)) / span
    }

    private func clamp01(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }
}

// MARK: - Tooltip Bubble

private struct TimelineTooltipBubble: View {
    let time:  String
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.onSurface)
                    .lineLimit(1)
            }
            Text(time)
                .font(.caption2)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Preview Data

private struct MiniTimelineStripPreviewData {
    static let cal = Calendar.current
    static let now = Date()

    static func event(_ title: String, hour: Int, minute: Int = 0,
                      duration: Double, category: EventCategory) -> Event {
        let start = cal.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        return Event(title: title, date: start,
                     endDate: start.addingTimeInterval(duration * 3600),
                     category: category)
    }

    static func task(_ title: String, hour: Int, duration: Double,
                     category: TaskCategory) -> DailyTask {
        let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        return DailyTask(title: title, date: now, startTime: start,
                         endTime: start.addingTimeInterval(duration * 3600),
                         category: category)
    }

    static let richDay: [Event] = [
        event("Stand-up",      hour: 9,  duration: 0.5, category: .meeting),
        event("Design Review", hour: 10, duration: 2.0, category: .work),
        event("Team Lunch",    hour: 12, duration: 1.5, category: .social),
        event("Overlap",       hour: 12, minute: 30, duration: 1.5, category: .entertainment),
        event("Coffee Chat",   hour: 15, duration: 1.0, category: .social),
        event("Dinner",        hour: 19, duration: 1.5, category: .general),
    ]

    static let mixedTasks: [DailyTask] = [
        task("Morning workout", hour: 7,  duration: 1.0, category: .health),
        task("Deep work",       hour: 14, duration: 2.0, category: .work),
    ]
}

#Preview("MiniTimelineStripView") {
    let data = MiniTimelineStripPreviewData.self
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Rich day — events + tasks + today indicator")
                    .font(.caption).foregroundStyle(AppTheme.onSurfaceVariant)
                MiniTimelineStripView(events: data.richDay, tasks: data.mixedTasks, selectedDate: data.now)
            }

            Group {
                Text("Tasks only (blocks + ticks)")
                    .font(.caption).foregroundStyle(AppTheme.onSurfaceVariant)
                MiniTimelineStripView(
                    events: [],
                    tasks: data.mixedTasks + [
                        DailyTask(title: "Quick errand", date: data.now,
                                  startTime: data.cal.date(bySettingHour: 11, minute: 0, second: 0, of: data.now)!,
                                  category: .errands)
                    ],
                    selectedDate: data.now
                )
            }

            Group {
                Text("Single event")
                    .font(.caption).foregroundStyle(AppTheme.onSurfaceVariant)
                MiniTimelineStripView(
                    events: [data.event("Morning Meeting", hour: 10, duration: 1, category: .meeting)],
                    tasks: [], selectedDate: data.now
                )
            }

            Group {
                Text("Empty — no timed items")
                    .font(.caption).foregroundStyle(AppTheme.onSurfaceVariant)
                MiniTimelineStripView(events: [], tasks: [],
                                      selectedDate: data.cal.date(byAdding: .day, value: -1, to: data.now)!)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
