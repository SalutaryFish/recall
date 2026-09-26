import RecallCore
import SwiftUI

/// Insights (§2.8): the week as prose first, charts second.
struct InsightsScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let today = store.today
        let week = InsightsBuilder.week(ending: today, entries: store.entries, now: Date(), calendar: store.calendar)
        VStack(spacing: 0) {
            PageHeader(kicker: "WEEK OF \(Fmt.dayMonth(today))", title: "Insights")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RecapCard(week: week)
                    SectionLabel("ATTENTION SPLIT")
                    SplitBar(week: week)
                    Text(splitNote(week))
                        .font(.mono(10))
                        .foregroundStyle(Palette.ink3)
                        .lineSpacing(5)
                        .padding(.top, 7)
                    SectionLabel("WHERE THE MEDIA WENT")
                    SourceList(sources: week.sources)
                    SectionLabel("COMPLETION")
                    HStack(spacing: 9) {
                        StatCard(value: "\(week.finished)", label: "FINISHED")
                        StatCard(value: "\(week.abandoned)", label: "ABANDONED")
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 146) }
        }
    }

    private func splitNote(_ week: WeekInsights) -> String {
        let total = max(1, week.total)
        let active = Int((week.activeMedia / total * 100).rounded())
        let background = Int((week.backgroundMedia / total * 100).rounded())
        return "\(active)% OF LOGGED TIME HAD YOUR ATTENTION ON MEDIA · \(background)% HAD MEDIA IN THE BACKGROUND"
    }
}

private struct RecapCard: View {
    let week: WeekInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("The week, briefly")
                .font(.serif(21))
                .foregroundStyle(Palette.ink)
            if week.isEmpty {
                paragraph(Text("Nothing logged this week yet. The recap writes itself as the days fill in."))
            } else {
                paragraph(
                    Text(
                        "Across \(em("\(week.dayCount) day\(week.dayCount == 1 ? "" : "s")")) you logged \(Fmt.duration(minutes: week.total)). Media took \(em(Fmt.duration(minutes: week.activeMedia))) of your actual attention — and a further \(Fmt.duration(minutes: week.backgroundMedia)) played while you were doing something else."
                    )
                )
                if let longest = week.longestFocus {
                    paragraph(
                        Text(
                            "Your longest unbroken stretch of focus was \(em(Fmt.duration(minutes: week.longestFocusMinutes))) on \(longest.title)\(longest.place.map { ", at \($0)" } ?? "")."
                        )
                    )
                }
                if let top = week.topSource {
                    paragraph(
                        Text(
                            "Most of the media time went to \(em(top.source.rawValue)) — \(Fmt.duration(minutes: top.minutes)) across \(week.mediaItems) items."
                        )
                    )
                }
                Text(week.abandoned > week.finished
                     ? "You abandon more than you finish. That is not a failing — it is just worth knowing."
                     : "You finish most of what you start. Unusual.")
                    .font(.serif(14))
                    .foregroundStyle(Palette.ink3)
                    .lineSpacing(6)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: 16)
    }

    private func em(_ text: String) -> Text {
        Text(text).font(.serifItalic(16)).foregroundStyle(Palette.ink)
    }

    private func paragraph(_ text: Text) -> some View {
        text
            .font(.serif(16))
            .foregroundStyle(Palette.ink2)
            .lineSpacing(8)
    }
}

private struct SplitBar: View {
    let week: WeekInsights

    var body: some View {
        let total = max(1, week.total)
        let parts: [(String, Double, Color)] = [
            ("MEDIA", week.activeMedia, Palette.toneMedia),
            ("BACKGROUND", week.backgroundMedia, Palette.toneMediaBackground),
            ("FOCUS", week.focus, Palette.toneFocus),
            ("REST", week.other, Palette.toneLife),
        ].filter { $0.1 > 0 }
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(parts.indices, id: \.self) { index in
                    let part = parts[index]
                    let share = CGFloat(part.1 / total)
                    ZStack(alignment: .leading) {
                        part.2
                        if share > 0.16 {
                            Text(part.0)
                                .font(.mono(10))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: proxy.size.width * share)
                }
            }
        }
        .frame(height: 30)
        .background(Palette.wash)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.top, 0)
        .accessibilityElement()
        .accessibilityLabel(parts.map { "\($0.0.lowercased()) \(Int(($0.1 / total * 100).rounded())) percent" }
            .joined(separator: ", "))
    }
}

private struct SourceList: View {
    let sources: [SourceShare]

    var body: some View {
        let most = max(1, sources.map(\.minutes).max() ?? 1)
        VStack(spacing: 0) {
            if sources.isEmpty {
                SheetSub("NO MEDIA LOGGED YET")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(sources) { share in
                HStack(spacing: 11) {
                    Text(share.source.label)
                        .font(.mono(10.5))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: 64, alignment: .leading)
                    Capsule()
                        .fill(Palette.wash)
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Palette.toneFocus)
                                    .frame(width: proxy.size.width * CGFloat(share.minutes / most))
                            }
                        }
                    Text(Fmt.duration(minutes: share.minutes))
                        .font(.mono(10.5))
                        .foregroundStyle(Palette.ink3)
                        .frame(width: 46, alignment: .trailing)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Palette.hair.frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
