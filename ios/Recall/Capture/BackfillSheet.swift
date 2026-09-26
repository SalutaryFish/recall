import RecallCore
import SwiftUI

/// Fill the gap (§2.2): the hole's start and end are already there — just name the thing.
struct BackfillSheet: View {
    @Environment(AppStore.self) private var store
    let from: Date
    let to: Date

    @State private var title = ""
    @State private var start: Date?
    @State private var end: Date?
    @State private var attention: Attention = .active
    @State private var editing: TimeField?

    enum TimeField { case from, to }

    var body: some View {
        let s = start ?? from
        let e = end ?? to
        let dayStart = Day(from, calendar: store.calendar).start(store.calendar)
        let latest = min(Day(from, calendar: store.calendar).end(store.calendar), max(Date(), to))
        FittedSheet(expanded: .constant(false)) {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle("Fill the gap")
                SheetSub("\(store.hhmm(s)) – \(store.hhmm(e)) · \(Fmt.duration(e.timeIntervalSince(s))) UNACCOUNTED")
                    .padding(.top, 2)
                InputField(placeholder: "what were you doing?", text: $title, submitLabel: .done)
                    .padding(.top, 14)
                SheetSub("LIKELY, GIVEN THE TIME")
                    .padding(.top, 16)
                FrequentsGrid(frequents: store.topFrequents(6, at: s), showUses: false) { frequent in
                    title = frequent.name
                }
                .padding(.top, 10)
                FieldList {
                    FieldRow(key: "FROM") {
                        TimeValueButton(text: store.hhmm(s), active: editing == .from) { toggle(.from) }
                    }
                    if editing == .from {
                        WheelTimePicker(selection: Binding(get: { start ?? from }, set: { start = $0 }),
                                        range: dayStart ... max(dayStart, e.addingTimeInterval(-60)))
                    }
                    FieldRow(key: "TO") {
                        TimeValueButton(text: store.hhmm(e), active: editing == .to) { toggle(.to) }
                    }
                    if editing == .to {
                        WheelTimePicker(selection: Binding(get: { end ?? to }, set: { end = $0 }),
                                        range: s.addingTimeInterval(60) ... max(latest, s.addingTimeInterval(60)))
                    }
                    FieldRow(key: "ATTENTION") {
                        SegmentedPill(options: Attention.allCases, label: { $0.rawValue.uppercased() },
                                      selection: $attention)
                    }
                }
                .padding(.top, 12)
                HStack(spacing: 10) {
                    Button("Add to the day") { save(from: s, to: e) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Leave it") { store.dismissSheet() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 16)
            }
        }
    }

    private func toggle(_ field: TimeField) {
        withAnimation(SpringPreset.snappy.animation) {
            editing = editing == field ? nil : field
        }
        Haptics.tick()
    }

    private func save(from s: Date, to e: Date) {
        store.dismissSheet()
        store.backfill(from: s, to: e, title: title, attention: attention)
    }
}
