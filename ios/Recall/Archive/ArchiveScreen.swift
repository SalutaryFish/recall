import RecallCore
import SwiftUI

/// Archive (§6.7): heatmap calendar, on-this-day, lifetime counts, search.
struct ArchiveScreen: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var preview: HeatPreview?
    @State private var hideTask: Task<Void, Never>?

    struct HeatPreview: Equatable {
        let day: Day
        let frame: CGRect
    }

    var body: some View {
        let today = store.today
        let now = Date()
        VStack(spacing: 0) {
            PageHeader(kicker: "\(Fmt.grouped(daysLogged)) DAYS LOGGED", title: "Archive")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("\(Fmt.monthYear(today)) · DARKER = MORE OF THE DAY CAPTURED")
                    heatmap(today: today, now: now)
                    if let otd = ArchiveMath.onThisDay(today: today, entries: store.entries, now: now,
                                                       calendar: store.calendar) {
                        OnThisDayCard(onThisDay: otd) { store.show(day: otd.day) }
                            .padding(.top, 18)
                    }
                    HStack(spacing: 9) {
                        StatCard(value: Fmt.grouped(store.data.counters.mediaSaved + store.data.counters.sampleMedia),
                                 label: "MEDIA SAVED")
                        StatCard(value: Fmt.grouped(hoursLogged(now: now)), label: "HOURS LOGGED")
                    }
                    .padding(.top, 14)
                    SectionLabel("SEARCH")
                    InputField(placeholder: "an evening, a video, a place…", text: $query, submitLabel: .search)
                    SearchResults(query: query)
                        .padding(.top, 8)
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 146) }
        }
        .coordinateSpace(.named("archive"))
        .overlay(alignment: .topLeading) {
            if let preview {
                DayPreviewCard(day: preview.day)
                    .frame(width: 190)
                    .position(x: preview.frame.midX, y: preview.frame.minY - 50)
                    .transition(.scale(scale: 0.94, anchor: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.16), value: preview)
    }

    private var daysLogged: Int {
        Set(store.entries.map { Day($0.start, calendar: store.calendar) }).count + store.data.counters.sampleDays
    }

    private func hoursLogged(now: Date) -> Int {
        let minutes = store.entries.filter { !$0.isPending }
            .reduce(0.0) { $0 + DayTimeline.lengthMinutes($1, now: now) }
        return Int((minutes / 60).rounded()) + store.data.counters.sampleHours
    }

    private func heatmap(today: Day, now: Date) -> some View {
        let grid = ArchiveMath.monthGrid(containing: today, calendar: store.calendar)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0 ..< 7, id: \.self) { index in
                    Text(["M", "T", "W", "T", "F", "S", "S"][index])
                        .font(.mono(9))
                        .foregroundStyle(Palette.ink3)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0 ..< grid.leadingBlanks, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
                ForEach(grid.days, id: \.self) { day in
                    HeatCell(day: day,
                             fill: ArchiveMath.fill(for: day, snapshot: store.data, now: now, calendar: store.calendar),
                             isToday: day == today,
                             isFuture: day > today,
                             onTap: { open(day, isFuture: day > today) },
                             onPress: { frame in press(day, frame: frame) },
                             onRelease: { release() })
                }
            }
        }
    }

    private func open(_ day: Day, isFuture: Bool) {
        guard !isFuture else { return }
        if store.entries(on: day).isEmpty {
            store.showToast("No detail kept for that day")
        } else {
            store.show(day: day)
        }
    }

    private func press(_ day: Day, frame: CGRect) {
        hideTask?.cancel()
        preview = HeatPreview(day: day, frame: frame)
        Haptics.thud()
    }

    private func release() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            preview = nil
        }
    }
}

private struct HeatCell: View {
    let day: Day
    let fill: Double
    let isToday: Bool
    let isFuture: Bool
    let onTap: () -> Void
    let onPress: (CGRect) -> Void
    let onRelease: () -> Void
    @State private var pressed = false

    var body: some View {
        let anchor = isToday || day.day == 1 || day.day % 7 == 1
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isFuture ? Color.clear : (isToday ? Palette.ink : Palette.heat[ArchiveMath.level(fill)]))
                .overlay {
                    if isFuture {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Palette.hair, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    }
                }
                .overlay {
                    if anchor {
                        Text("\(day.day)")
                            .font(.mono(10))
                            .foregroundStyle(isToday || (!isFuture && fill > 0.5) ? Palette.bone : Palette.ink3)
                    }
                }
                .scaleEffect(pressed ? 0.9 : 1)
                .animation(.easeOut(duration: 0.15), value: pressed)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 10) {
                    onPress(proxy.frame(in: .named("archive")))
                } onPressingChanged: { isPressing in
                    pressed = isPressing
                    if !isPressing { onRelease() }
                }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("\(Fmt.shortDate(day))\(isToday ? ", today" : "")")
        .accessibilityValue(isFuture ? "not yet" : "\(Int((fill * 100).rounded())) percent captured")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
    }
}

/// G12: what that day was, while the finger is down.
private struct DayPreviewCard: View {
    @Environment(AppStore.self) private var store
    let day: Day

    var body: some View {
        let now = Date()
        let entries = store.entries(on: day, now: now).filter { !$0.isPending }
        let fill = ArchiveMath.fill(for: day, snapshot: store.data, now: now, calendar: store.calendar)
        let tracked = entries.reduce(0.0) {
            $0 + DayTimeline.clippedMinutes($1, day: day, now: now, calendar: store.calendar)
        }
        let highlight = (entries.first { $0.category.isMedia } ?? entries.first)?.title
        VStack(alignment: .leading, spacing: 5) {
            Text(Fmt.compactDate(day, calendar: store.calendar))
                .font(.mono(10))
                .tracking(0.8)
                .foregroundStyle(Palette.ink3)
            Group {
                if day > store.today {
                    Text("Not yet.")
                } else if entries.isEmpty {
                    Text(verbatim: "\(Int((fill * 100).rounded()))% of the day captured.")
                } else {
                    Text(verbatim: "\(entries.count) entries · \(Fmt.duration(minutes: tracked)) tracked."
                        + (highlight.map { "\n\($0)" } ?? ""))
                }
            }
            .sans(13)
            .foregroundStyle(Palette.ink)
            .lineSpacing(3)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(Palette.card)
                .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(Palette.hair, lineWidth: 1)
        }
    }
}

private struct OnThisDayCard: View {
    let onThisDay: ArchiveMath.OnThisDay
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ON THIS DAY · 1 YEAR AGO")
                .font(.mono(10.5))
                .tracking(0.8)
                .foregroundStyle(Palette.clayInk)
            Text(onThisDay.text)
                .sans(14)
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
                .padding(.top, 8)
            Button(action: action) {
                Text("Re-live that day →")
                    .font(.mono(11))
                    .foregroundStyle(Palette.ink2)
                    .padding(.bottom, 1)
                    .overlay(alignment: .bottom) { Palette.hair2.frame(height: 1) }
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.top, 14)
        .padding(.horizontal, 15)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: 16)
    }
}

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.serif(23))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.mono(9.5))
                .tracking(0.7)
                .foregroundStyle(Palette.ink3)
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}

private struct SearchResults: View {
    @Environment(AppStore.self) private var store
    let query: String

    var body: some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2 {
            let hits = Suggestions.search(trimmed, in: store.entries)
            VStack(spacing: 0) {
                if hits.isEmpty {
                    Text("Nothing matches")
                        .sans(14)
                        .foregroundStyle(Palette.ink3)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 14)
                }
                ForEach(hits) { entry in
                    Button {
                        store.open(.detail(entry.id))
                    } label: {
                        HStack(spacing: 10) {
                            Text(entry.source?.glyph ?? "▪")
                                .font(.mono(9.5))
                                .foregroundStyle(Palette.ink2)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Palette.wash, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                            Text(entry.title)
                                .sans(14)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(Fmt.shortDate(Day(entry.start, calendar: store.calendar)))
                                .font(.mono(10))
                                .foregroundStyle(Palette.ink3)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        if entry.id != hits.last?.id { Palette.hair.frame(height: 1) }
                    }
                }
            }
            .cardSurface()
        }
    }
}
