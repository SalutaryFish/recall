import RecallCore
import SwiftUI

/// Quick add (§6.3): type with autocomplete from your own history, or one tap on a frequent.
struct QuickAddSheet: View {
    @Environment(AppStore.self) private var store
    let switching: Bool
    @State private var query = ""
    @State private var place: String?
    @State private var expanded = false
    @FocusState private var focused: Bool

    var body: some View {
        let now = Date()
        let frequents = store.topFrequents(6, at: now)
        let hits = Suggestions.autocomplete(query, entries: store.entries,
                                            hour: store.calendar.component(.hour, from: now),
                                            calendar: store.calendar)
        FittedSheet(canExpand: true, expanded: $expanded) {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle(switching ? "Switch to" : "Log something")
                SheetSub("\(store.hhmm(now)) · RIGHT NOW\(place.map { " · @ \($0.uppercased())" } ?? "")")
                    .padding(.top, 2)
                InputField(placeholder: "what are you doing?", text: $query, focus: $focused,
                           submitLabel: .go, onSubmit: { startNow() })
                    .padding(.top, 14)
                if !hits.isEmpty {
                    SuggestionList(suggestions: hits) { suggestion in pick(suggestion) }
                        .padding(.top, 8)
                }
                SheetSub("ONE-TAP — YOUR FREQUENTS")
                    .padding(.top, 18)
                FrequentsGrid(frequents: frequents, showUses: true) { frequent in
                    store.dismissSheet()
                    store.startBlock(frequent.name, category: frequent.category, place: place)
                }
                .padding(.top, 10)
                HStack(spacing: 10) {
                    Button("Start now") { startNow() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Past") { past() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 16)
            }
        }
        .onChange(of: focused) { _, isFocused in
            if isFocused { expanded = true }
        }
        .accessibilityIdentifier("sheet.quickAdd")
    }

    private func startNow() {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = typed.isEmpty ? (store.topFrequents(1).first?.name ?? "Untitled") : typed
        let category = store.data.frequents.first { $0.name.lowercased() == title.lowercased() }?.category ?? .life
        store.dismissSheet()
        store.startBlock(title, category: category, place: place)
    }

    private func past() {
        let now = Date()
        let lastEnd = store.entries(on: store.today, now: now).last.map { DayTimeline.effectiveEnd($0, now: now) }
        var from = lastEnd ?? now.addingTimeInterval(-3600)
        if now.timeIntervalSince(from) < 5 * 60 { from = now.addingTimeInterval(-3600) }
        store.sheet = .backfill(from: from, to: now)
    }

    private func pick(_ suggestion: Suggestion) {
        switch suggestion.kind {
        case .block:
            let category = store.data.frequents.first { $0.name == suggestion.text }?.category ?? .life
            store.dismissSheet()
            store.startBlock(suggestion.text, category: category, place: place)
        case .place:
            place = suggestion.text
            query = ""
            Haptics.tick()
        }
    }
}

/// `.ac`: autocomplete rows (BLOCK / PLACE).
struct SuggestionList: View {
    let suggestions: [Suggestion]
    let onPick: (Suggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    onPick(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Text(suggestion.kind.rawValue)
                            .font(.mono(9.5))
                            .tracking(0.6)
                            .foregroundStyle(Palette.ink2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Palette.wash, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Text(suggestion.text)
                            .sans(14)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if suggestion.kind == .block {
                            Text("used \(suggestion.uses)×")
                                .font(.mono(10))
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    if suggestion.id != suggestions.last?.id { Palette.hair.frame(height: 1) }
                }
            }
        }
        .cardSurface()
    }
}
