import Observation
import RecallCore
import SwiftUI

/// Scroll-driven header state. Only `DayTitle` reads `collapse`, so scrolling
/// re-renders the title and nothing else.
@Observable
final class ScrollChrome {
    /// 0…1 over the first 64 pt of scroll.
    var collapse: CGFloat = 0
    @ObservationIgnored var pull: CGFloat = 0
    @ObservationIgnored var armed = false
    @ObservationIgnored var interacting = false
}

/// `.thead`: date label, serif day title, stats, density chip, 24h ribbon.
struct DayHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    let pager: SpringValue
    let chrome: ScrollChrome
    let densityPreview: Density?
    let onScrub: (Double?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PagerOffset(pager: pager) {
                top
            }
            DayRibbon(onScrub: onScrub)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 14)
        .background(Palette.bone)
        .contentShape(Rectangle())
    }

    private var top: some View {
        let day = store.day
        let today = store.today
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Fmt.dateLabel(day, calendar: store.calendar))
                        .font(.mono(11.5))
                        .tracking(0.9)
                        .foregroundStyle(Palette.ink3)
                    DayTitle(text: Fmt.dayTitle(day, today: today, calendar: store.calendar), chrome: chrome)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    IconButton(systemImage: "circle.lefthalf.filled", label: "Theme") {
                        store.toggleTheme(currentlyDark: colorScheme == .dark)
                    }
                    IconButton(systemImage: "arrow.down.to.line", label: "Save a link") {
                        store.open(.share)
                    }
                }
                .padding(.top, -8)
                .padding(.trailing, -8)
            }
            TimelineView(.everyMinute) { context in
                DayStatsLine(stats: DayTimeline.stats(for: store.entries(on: day, now: context.date), day: day,
                                                      now: context.date, calendar: store.calendar))
            }
            .padding(.top, 7)
            HStack(spacing: 8) {
                if day < today {
                    Pill(text: "TODAY →", dot: false) { store.show(day: today) }
                        .accessibilityLabel("Back to today")
                }
                Spacer(minLength: 0)
                Pill(text: densityPreview.map { "→ \($0.label)" } ?? store.data.density.label, dot: true) {
                    store.cycleDensity()
                }
                .accessibilityLabel("Density: \(store.data.density.label.lowercased())")
                .accessibilityHint("Pinch the timeline, or tap to cycle transcript, proportional and ribbon.")
            }
            .padding(.top, 9)
        }
    }
}

struct DayTitle: View {
    let text: String
    let chrome: ScrollChrome

    var body: some View {
        let t = chrome.collapse
        Text(text)
            .font(.serif(32, relativeTo: .largeTitle))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .scaleEffect(1 - t * 0.22, anchor: .leading)
            .offset(y: -t * 6)
            .opacity(1 - t * 0.45)
            .accessibilityAddTraits(.isHeader)
    }
}

/// "6h12m tracked · 1h40m media attention · 14 items", numbers in ink.
struct DayStatsLine: View {
    let stats: DayStats

    var body: some View {
        Group {
            if stats.entryCount == 0 {
                Text("nothing logged yet")
            } else {
                Text(
                    "\(bold(Fmt.duration(minutes: stats.trackedMinutes))) tracked · \(bold(Fmt.duration(minutes: stats.mediaAttentionMinutes))) media attention · \(stats.mediaItems) item\(stats.mediaItems == 1 ? "" : "s")"
                )
            }
        }
        .font(.mono(11.5))
        .tracking(0.3)
        .foregroundStyle(Palette.ink3)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func bold(_ text: String) -> Text {
        Text(text).font(.mono(11.5, medium: true)).foregroundStyle(Palette.ink)
    }
}

/// The small floating pill used for density (`.dens`) and the jump back to today.
struct Pill: View {
    let text: String
    let dot: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if dot {
                    Circle().fill(Palette.clay).frame(width: 5, height: 5)
                }
                Text(text)
                    .font(.mono(9.5))
                    .tracking(1)
                    .foregroundStyle(Palette.ink2)
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background {
                Capsule()
                    .fill(Palette.card)
                    .shadow(color: Palette.shadowCard, radius: 1, x: 0, y: 1)
            }
            .overlay { Capsule().strokeBorder(Palette.hair, lineWidth: 1) }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.96))
        .padding(.vertical, -8)
    }
}

/// Applies the day-paging offset (G9) without re-rendering its content every frame.
struct PagerOffset<Content: View>: View {
    let pager: SpringValue
    @ViewBuilder var content: Content

    var body: some View {
        let x = pager.value
        content
            .offset(x: x)
            .opacity(1 - min(1, abs(x) / 240) * 0.7)
    }
}

/// The 24h ribbon (§2.4): a summary and a scrubber in one (G11).
struct DayRibbon: View {
    @Environment(AppStore.self) private var store
    let onScrub: (Double?) -> Void
    @State private var scrub: Double?
    @State private var width: CGFloat = 0

    var body: some View {
        VStack(spacing: 2) {
            TimelineView(.everyMinute) { context in
                track(now: context.date)
            }
            .frame(height: 22)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newValue in
                width = newValue
            }
            .overlay(alignment: .topLeading) { cursor }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let f: Double = width > 0 ? Double(min(1, max(0, value.location.x / width))) : 0
                        if scrub == nil { Haptics.tick() }
                        scrub = f
                        onScrub(f)
                    }
                    .onEnded { _ in
                        scrub = nil
                        onScrub(nil)
                    }
            )
            HStack {
                Text("00")
                Spacer()
                Text("06")
                Spacer()
                Text("12")
                Spacer()
                Text("18")
                Spacer()
                Text("24")
            }
            .font(.mono(9.5))
            .tracking(0.6)
            .foregroundStyle(Palette.ink3)
            .opacity(0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day ribbon")
        .accessibilityHint("Drag to jump through the day.")
    }

    private func track(now: Date) -> some View {
        let day = store.day
        let entries = store.entries(on: day, now: now)
        let segments = DayTimeline.ribbon(for: entries, day: day, now: now, calendar: store.calendar)
            .map { ($0.from, $0.to, Palette.tone($0.category)) }
        let nowFraction: Double? = day.contains(now, calendar: store.calendar)
            ? DayTimeline.fraction(of: now, in: day, calendar: store.calendar) : nil
        return ZStack(alignment: .leading) {
            ZStack {
                Hatch(angle: 115, first: Palette.wash, firstWidth: 3, second: Palette.wash2, secondWidth: 3)
                Canvas { context, size in
                    for segment in segments {
                        let rect = CGRect(x: segment.0 * size.width, y: 0,
                                          width: max(0.5, (segment.1 - segment.0) * size.width), height: size.height)
                        context.fill(Path(rect), with: .color(segment.2))
                    }
                }
            }
            .frame(height: 7)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            if let nowFraction {
                Rectangle()
                    .fill(Palette.ink)
                    .frame(width: 1.5, height: 15)
                    .offset(x: CGFloat(nowFraction) * width - 0.75)
            }
        }
    }

    @ViewBuilder private var cursor: some View {
        if let scrub {
            let x = CGFloat(scrub) * width
            let date = DayTimeline.date(atFraction: scrub, in: store.day, calendar: store.calendar)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Palette.clay)
                    .frame(width: 2, height: 21)
                    .offset(x: x - 1, y: 1)
                Text(store.hhmm(date))
                    .font(.mono(11))
                    .foregroundStyle(Palette.bone)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .fixedSize()
                    .position(x: min(max(x, 22), max(22, width - 22)), y: -15)
            }
            .frame(width: width, height: 22, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }
}
