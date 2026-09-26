import RecallCore
import SwiftUI

/// The card inside a timeline row: block, live block, media, session, moment or pending
/// detection (the prototype's `cardFor`).
struct EntryCard: View {
    @Environment(AppStore.self) private var store
    let entry: LogEntry
    let now: Date
    var expanded = false

    var body: some View {
        if entry.isPending {
            PendingCard(entry: entry, now: now)
        } else {
            switch entry.kind {
            case .moment: moment
            case .session: session
            case .media: media
            case .block: block
            }
        }
    }

    private var minutes: Double { DayTimeline.lengthMinutes(entry, now: now) }

    // MARK: kinds

    private var moment: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
            if let meta = entry.meta {
                MetaLine(meta)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    private var block: some View {
        let live = entry.isLive
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                title
                Spacer(minLength: 0)
                Text(live ? "● \(Fmt.duration(minutes: minutes))" : Fmt.duration(minutes: minutes))
                    .font(.mono(11))
                    .foregroundStyle(live ? Palette.clayInk : Palette.ink3)
                    .fixedSize()
            }
            if entry.place != nil || live {
                MetaLine([entry.place.map { "@ \($0)" }, live ? "in progress" : nil]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .padding(.top, 4)
            }
            if !entry.tags.isEmpty {
                ChipRow(tags: entry.tags)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(border: live ? Palette.clay.opacity(0.3) : Palette.hair)
    }

    private var media: some View {
        let background = entry.isBackground
        let glyph = entry.source?.glyph ?? MediaSource.web.glyph
        return HStack(spacing: 11) {
            Thumb(glyph: glyph, width: background ? 52 : 76, height: 52)
            VStack(alignment: .leading, spacing: 0) {
                title
                MetaLine([entry.source?.label, entry.creator].compactMap { $0 }.joined(separator: " · "))
                    .padding(.top, 4)
                if let percent = entry.completionPercent {
                    ProgressLine(fraction: Double(percent) / 100)
                        .padding(.top, 6)
                }
                HStack(spacing: 8) {
                    AttentionLabel(background: background)
                    Spacer(minLength: 0)
                    Text([entry.completionPercent.map { "\($0)%" }, Fmt.duration(minutes: minutes)]
                        .compactMap { $0 }
                        .joined(separator: " · "))
                        .font(.mono(10.5))
                        .foregroundStyle(Palette.ink3)
                }
                .padding(.top, 5)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .opacity(background ? 0.72 : 1)
    }

    private var session: some View {
        let items = entry.items ?? []
        let average = items.isEmpty ? 0 : items.reduce(0) { $0 + ($1.consumedMs ?? 0) } / items.count
        let glyph = entry.source?.glyph ?? MediaSource.web.glyph
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                title
                Spacer(minLength: 0)
                Text(Fmt.duration(minutes: minutes))
                    .font(.mono(11))
                    .foregroundStyle(Palette.ink3)
                    .fixedSize()
            }
            MetaLine("\(entry.source?.label ?? "WEB") · \(items.count) items · avg \(Fmt.seconds(ms: average)) each")
                .padding(.top, 4)
            if expanded {
                VStack(spacing: 0) {
                    ForEach(items.prefix(6)) { item in
                        HStack(spacing: 9) {
                            Thumb(glyph: glyph, width: 38, height: 26, radius: 5, glyphSize: 11)
                            Text(item.title)
                                .sans(12.5)
                                .foregroundStyle(Palette.ink2)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(Fmt.seconds(ms: item.consumedMs))
                                .font(.mono(10))
                                .foregroundStyle(Palette.ink3)
                        }
                        .padding(.vertical, 7)
                        .overlay(alignment: .top) { Palette.hair.frame(height: 1) }
                    }
                    if items.count > 6 {
                        MetaLine("+ \(items.count - 6) MORE")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 5) {
                Text("▾")
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                Text(expanded ? "TAP TO FOLD" : "TAP FOR ALL \(items.count) ITEMS")
            }
            .font(.mono(10))
            .foregroundStyle(Palette.ink3)
            .padding(.top, 8)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }

    private var title: some View {
        Text(entry.title)
            .sans(14.5, .medium)
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
    }
}

/// An auto-captured entry waiting to be confirmed (§6.6): dashed clay, KEEP / DISCARD.
private struct PendingCard: View {
    @Environment(AppStore.self) private var store
    let entry: LogEntry
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "DETECTED · \(Int(((entry.confidence ?? 0.8) * 100).rounded()))% CONFIDENT")
                .font(.mono(9.5))
                .tracking(0.7)
                .foregroundStyle(Palette.clayInk)
                .padding(.bottom, 5)
            HStack(spacing: 10) {
                Text(entry.title)
                    .sans(14.5, .medium)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(Fmt.duration(minutes: DayTimeline.lengthMinutes(entry, now: now)))
                    .font(.mono(11))
                    .foregroundStyle(Palette.ink3)
                    .fixedSize()
            }
            MetaLine([entry.source?.label, entry.creator ?? entry.place,
                      entry.completionPercent.flatMap { $0 > 0 ? "\($0)%" : nil }]
                .compactMap { $0 }
                .joined(separator: " · "))
                .padding(.top, 4)
            HStack(spacing: 7) {
                Button("KEEP") { store.confirm(entry) }
                    .buttonStyle(PendingButtonStyle(primary: true))
                    .accessibilityIdentifier("pending.keep")
                Button("DISCARD") { store.discard(entry) }
                    .buttonStyle(PendingButtonStyle(primary: false))
            }
            .padding(.top, 9)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(Palette.clayWash)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(Palette.clay, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }
}

private struct PendingButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(10.5))
            .tracking(0.7)
            .foregroundStyle(primary ? Palette.bone : Palette.ink2)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(primary ? Palette.ink : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(primary ? Palette.ink : Palette.hair2, lineWidth: 1)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .padding(.vertical, -5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct MetaLine: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.mono(10.5))
            .foregroundStyle(Palette.ink3)
            .lineLimit(1)
    }
}

struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(Palette.wash2)
            .frame(height: 3)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Palette.clay)
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
    }
}

/// "● ACTIVE" / "○ BACKGROUND".
struct AttentionLabel: View {
    let background: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(background ? Color.clear : Palette.clay)
                .overlay { Circle().strokeBorder(background ? Palette.ink3 : Color.clear, lineWidth: 1) }
                .frame(width: 5, height: 5)
            Text(background ? "BACKGROUND" : "ACTIVE")
                .font(.mono(9.5))
                .tracking(0.6)
                .foregroundStyle(Palette.ink3)
        }
    }
}
