import RecallCore
import SwiftUI

/// Entry detail (§6.5) — also where every row gesture has its visible fallback:
/// edit (title, times, place, thought), split, delete, do again.
struct EntryDetailSheet: View {
    @Environment(AppStore.self) private var store
    let entryID: UUID
    @State private var editing: TimeField?

    enum TimeField { case from, to }

    var body: some View {
        Group {
            if let entry = store.entry(entryID) {
                content(entry)
            } else {
                Color.clear.onAppear { store.dismissSheet() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func content(_ entry: LogEntry) -> some View {
        let now = Date()
        let isMedia = entry.kind == .media || entry.kind == .session
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetSub(
                    "\(store.hhmm(entry.start)) – \(entry.end.map { store.hhmm($0) } ?? "NOW") · \(Fmt.duration(minutes: DayTimeline.lengthMinutes(entry, now: now)))"
                )
                hero(entry, isMedia: isMedia)
                TextField("", text: titleBinding(entry), prompt: Text("Untitled").foregroundStyle(Palette.ink3),
                          axis: .vertical)
                    .font(.serif(24))
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                    .padding(.top, 14)
                SheetSub([entry.source?.label, entry.creator, entry.place.map { "@ \($0)" }]
                    .compactMap { $0 }.joined(separator: " · ").ifEmpty("—"))
                    .padding(.top, 2)

                if entry.isPending {
                    pendingActions(entry)
                }
                if entry.kind == .media {
                    mediaFields(entry)
                }
                if entry.kind == .session {
                    sessionItems(entry)
                }
                timeFields(entry, now: now)
                thought(entry)
                if !entry.tags.isEmpty {
                    ChipRow(tags: entry.tags)
                        .padding(.top, 14)
                }
                provenance(entry)
                HStack(spacing: 10) {
                    Button("Do this again") {
                        store.dismissSheet()
                        store.again(entry)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Split") { store.split(entry) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(entry.isLive)
                        .opacity(entry.isLive ? 0.45 : 1)
                    Button("Delete") { store.delete(entry) }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    // MARK: pieces

    @ViewBuilder private func hero(_ entry: LogEntry, isMedia: Bool) -> some View {
        if let name = entry.photos?.first, let image = store.photo(named: name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 168)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 12)
                .accessibilityLabel("Photo from this block")
        } else if isMedia {
            Hatch.placeholder(band: 9)
                .frame(height: 168)
                .overlay {
                    Text(entry.source?.glyph ?? MediaSource.web.glyph)
                        .font(.system(size: 40))
                        .foregroundStyle(Palette.ink)
                        .opacity(0.6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(0.9)
                .padding(.top, 12)
        }
    }

    private func pendingActions(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "DETECTED · \(Int(((entry.confidence ?? 0.8) * 100).rounded()))% CONFIDENT")
                .font(.mono(10))
                .tracking(0.7)
                .foregroundStyle(Palette.clayInk)
            HStack(spacing: 10) {
                Button("Keep") { store.confirm(entry) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Discard") {
                    store.dismissSheet()
                    store.discard(entry)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.top, 14)
    }

    private func mediaFields(_ entry: LogEntry) -> some View {
        let percent = entry.completionPercent
        return VStack(alignment: .leading, spacing: 14) {
            FieldList {
                if let duration = entry.durationMs {
                    FieldRow(key: "CONSUMED") {
                        Text(
                            "\(Int((Double(entry.consumedMs ?? 0) / 60_000).rounded()))m of \(Int((Double(duration) / 60_000).rounded()))m"
                        )
                            .sans(13.5)
                            .foregroundStyle(Palette.ink)
                    }
                }
                FieldRow(key: "ATTENTION") {
                    SegmentedPill(options: Attention.allCases, label: { $0.rawValue.uppercased() },
                                  selection: Binding(get: { entry.attention ?? .active },
                                                     set: { store.setAttention(entry, $0) }))
                }
            }
            if let percent {
                HStack(spacing: 14) {
                    CompletionRing(percent: percent)
                    VStack(alignment: .leading, spacing: 4) {
                        SheetSub(percent >= 95 ? "FINISHED" : percent >= 50 ? "MOSTLY WATCHED" : "ABANDONED EARLY")
                        SheetSub("\(percent)% OF THE RUNTIME")
                    }
                }
            }
        }
        .padding(.top, 14)
    }

    private func sessionItems(_ entry: LogEntry) -> some View {
        let items = entry.items ?? []
        let average = items.isEmpty ? 0 : items.reduce(0) { $0 + ($1.consumedMs ?? 0) } / items.count
        return VStack(alignment: .leading, spacing: 8) {
            SheetSub("\(items.count) ITEMS · AVG \(Fmt.seconds(ms: average))")
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Text(entry.source?.glyph ?? "⌗")
                            .font(.mono(9.5))
                            .foregroundStyle(Palette.ink2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Palette.wash, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Text(item.title)
                            .sans(14)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(Fmt.seconds(ms: item.consumedMs))
                            .font(.mono(10))
                            .foregroundStyle(Palette.ink3)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .overlay(alignment: .bottom) {
                        if item.id != items.last?.id { Palette.hair.frame(height: 1) }
                    }
                }
            }
            .cardSurface()
        }
        .padding(.top, 14)
    }

    private func timeFields(_ entry: LogEntry, now: Date) -> some View {
        let day = Day(entry.start, calendar: store.calendar)
        let dayStart = day.start(store.calendar)
        let end = entry.end
        return FieldList {
            FieldRow(key: "FROM") {
                TimeValueButton(text: store.hhmm(entry.start), active: editing == .from) { toggle(.from) }
            }
            if editing == .from {
                WheelTimePicker(selection: Binding(get: { entry.start }, set: { setStart(entry, $0) }),
                                range: dayStart ... max(dayStart, (end ?? now).addingTimeInterval(-60)))
            }
            FieldRow(key: "TO") {
                if let end {
                    TimeValueButton(text: store.hhmm(end), active: editing == .to) { toggle(.to) }
                } else {
                    Text("NOW")
                        .font(.mono(11))
                        .foregroundStyle(Palette.clayInk)
                }
            }
            if editing == .to, let end {
                let upper = max(entry.start.addingTimeInterval(60), min(day.end(store.calendar), max(now, end)))
                WheelTimePicker(selection: Binding(get: { end }, set: { setEnd(entry, $0) }),
                                range: entry.start.addingTimeInterval(60) ... upper)
            }
            FieldRow(key: "PLACE") {
                TextField("", text: placeBinding(entry),
                          prompt: Text("add a place").foregroundStyle(Palette.ink3))
                    .sans(13.5)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
            }
        }
        .padding(.top, 14)
    }

    private func thought(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SheetSub("THOUGHT")
            TextField("", text: noteBinding(entry), prompt: Text("+ add a thought").foregroundStyle(Palette.ink3),
                      axis: .vertical)
                .font(.serifItalic(17))
                .foregroundStyle(Palette.ink)
                .lineSpacing(6)
        }
        .padding(.top, 18)
    }

    private func provenance(_ entry: LogEntry) -> some View {
        let origin: String
        switch entry.origin {
        case .auto: origin = "AUTO-DETECTED"
        case .share: origin = "SHARED FROM A LINK"
        case .manual: origin = "LOGGED BY YOU"
        }
        let confidence = entry.confidence.map { " · \(Int(($0 * 100).rounded()))% CONFIDENT" } ?? ""
        return HStack(spacing: 6) {
            Circle().fill(Palette.ink3).frame(width: 4, height: 4)
            Text(verbatim: origin + confidence)
                .font(.mono(10))
                .tracking(0.5)
                .foregroundStyle(Palette.ink3)
        }
        .padding(.top, 14)
    }

    // MARK: editing

    private func titleBinding(_ entry: LogEntry) -> Binding<String> {
        Binding(get: { store.entry(entryID)?.title ?? entry.title },
                set: { value in edit { $0.title = value } })
    }

    private func placeBinding(_ entry: LogEntry) -> Binding<String> {
        Binding(get: { store.entry(entryID)?.placeText ?? entry.placeText },
                set: { value in edit { $0.placeText = value } })
    }

    private func noteBinding(_ entry: LogEntry) -> Binding<String> {
        Binding(get: { store.entry(entryID)?.noteText ?? entry.noteText },
                set: { value in edit { $0.noteText = value } })
    }

    /// Writes an edit straight through to the store; the timeline behind the sheet follows live.
    private func edit(_ change: (inout LogEntry) -> Void) {
        guard var current = store.entry(entryID) else { return }
        change(&current)
        store.update(current)
    }

    private func toggle(_ field: TimeField) {
        withAnimation(SpringPreset.snappy.animation) {
            editing = editing == field ? nil : field
        }
        Haptics.tick()
    }

    private func setStart(_ entry: LogEntry, _ date: Date) {
        guard var current = store.entry(entryID) else { return }
        current.start = date
        store.update(current)
    }

    private func setEnd(_ entry: LogEntry, _ date: Date) {
        guard var current = store.entry(entryID) else { return }
        current.end = max(date, current.start.addingTimeInterval(60))
        store.update(current)
    }
}

/// Completion arc for media (§6.5).
struct CompletionRing: View {
    let percent: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.wash2, lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(Palette.clay, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: "\(percent)%")
                .font(.mono(11))
                .foregroundStyle(Palette.ink)
        }
        .frame(width: 48, height: 48)
        .padding(4)
        .accessibilityElement()
        .accessibilityLabel("\(percent) percent watched")
    }
}

extension LogEntry {
    /// Editable views of optional text fields.
    var placeText: String {
        get { place ?? "" }
        set { place = newValue.isEmpty ? nil : newValue }
    }

    var noteText: String {
        get { note ?? "" }
        set { note = newValue.isEmpty ? nil : newValue }
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
