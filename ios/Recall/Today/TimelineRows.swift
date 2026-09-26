import RecallCore
import SwiftUI

/// The day's rows, refreshed every minute so live durations and the trailing gap stay honest.
struct TimelineContent: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        TimelineView(.everyMinute) { context in
            rows(now: context.date)
        }
    }

    @ViewBuilder private func rows(now: Date) -> some View {
        let day = store.day
        let entries = store.entries(on: day, now: now)
        let rows = DayTimeline.rows(for: entries, day: day, now: now, calendar: store.calendar)
        if rows.isEmpty {
            EmptyDayView(isToday: day == store.today)
        } else {
            let lastID = rows.last?.id
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    switch row {
                    case .entry(let entry):
                        EntryRow(entry: entry, isLast: row.id == lastID, now: now)
                            .id(row.id)
                    case .gap(let start, let end):
                        GapRow(start: start, end: end)
                            .id(row.id)
                    }
                }
            }
        }
    }
}

/// Untracked time as a first-class row (§2.2): hatched, dashed, one tap to fill.
struct GapRow: View {
    @Environment(AppStore.self) private var store
    let start: Date
    let end: Date

    var body: some View {
        let minutes = end.timeIntervalSince(start) / 60
        let height = DayTimeline.rowHeight(minutes: minutes, density: store.data.density)
        HStack(alignment: .top, spacing: 0) {
            Text(store.hhmm(start))
                .font(.mono(11.5))
                .foregroundStyle(Palette.ink3)
                .frame(width: 50, alignment: .leading)
                .padding(.top, 14)
                .accessibilityHidden(true)
            Button {
                store.open(.backfill(from: start, to: end))
            } label: {
                HStack(spacing: 9) {
                    Text("\(Fmt.duration(minutes: minutes)) untracked · \(store.hhmm(start))–\(store.hhmm(end))")
                        .font(.mono(11))
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Circle()
                        .fill(Palette.ink)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Text("+")
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.bone)
                                .offset(y: -1)
                        }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background {
                    Hatch(angle: 115, first: .clear, firstWidth: 5, second: Palette.wash, secondWidth: 5)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                        .strokeBorder(Palette.hair2, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle(scale: 0.985))
            .accessibilityLabel("\(Fmt.duration(minutes: minutes)) untracked, \(store.hhmm(start)) to \(store.hhmm(end))")
            .accessibilityHint("Fill the gap")
            .padding(.leading, 17.5)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, minHeight: height.map { CGFloat($0) }, alignment: .topLeading)
            .background(alignment: .leading) {
                DashedSpine()
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 2)
    }
}

private struct DashedSpine: View {
    var body: some View {
        let color = Palette.hair2
        Canvas { context, size in
            var line = Path()
            line.move(to: CGPoint(x: 0.75, y: 0))
            line.addLine(to: CGPoint(x: 0.75, y: size.height))
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        }
        .frame(width: 1.5)
        .accessibilityHidden(true)
    }
}

/// A first day: a hatched ribbon above, one serif line, and the frequents raised inline (§6.8).
struct EmptyDayView: View {
    @Environment(AppStore.self) private var store
    let isToday: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(isToday ? "Nothing yet.\nStart the day." : "Nothing kept\nfor this day.")
                .font(.serif(23))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Text(isToday ? "HOLD ⊕ FOR YOUR FREQUENTS\nOR TAP TO LOG SOMETHING" : "SWIPE THE HEADER FOR ANOTHER DAY")
                .font(.mono(11))
                .foregroundStyle(Palette.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .padding(.top, 8)
            if isToday {
                FrequentsGrid(frequents: store.topFrequents(6), showUses: false) { frequent in
                    store.startBlock(frequent.name, category: frequent.category)
                }
                .padding(.top, 22)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 56)
    }
}

/// Pull down at the top (G10): how the previous day ended.
struct YesterdayPeek: View {
    @Environment(AppStore.self) private var store
    let day: Day

    var body: some View {
        let entries = store.entries(on: day).suffix(3)
        VStack(alignment: .leading, spacing: 0) {
            Text(
                day == store.today.adding(days: -1, calendar: store.calendar) ? "HOW YESTERDAY ENDED" : "HOW THE DAY BEFORE ENDED"
            )
                .font(.mono(10))
                .tracking(0.9)
                .foregroundStyle(Palette.ink3)
                .padding(.bottom, 6)
            if entries.isEmpty {
                Text("Nothing was kept.")
                    .sans(13)
                    .foregroundStyle(Palette.ink2)
            }
            ForEach(Array(entries)) { entry in
                HStack(spacing: 10) {
                    Text(store.hhmm(entry.start))
                        .font(.mono(11))
                        .foregroundStyle(Palette.ink3)
                        .frame(width: 44, alignment: .leading)
                    Text(entry.title)
                        .sans(13)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(1)
                }
                .padding(.vertical, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Palette.wash)
        .overlay(alignment: .bottom) { Palette.hair.frame(height: 1) }
        .padding(.bottom, 6)
    }
}
