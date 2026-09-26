import Foundation

public struct SourceShare: Hashable, Sendable, Identifiable {
    public var source: MediaSource
    public var minutes: Double
    public var id: String { source.rawValue }
}

/// The week in numbers — the Insights tab and its written recap (§2.8, §6.7).
public struct WeekInsights: Sendable {
    public var dayCount: Int
    public var activeMedia: Double
    public var backgroundMedia: Double
    public var focus: Double
    public var other: Double
    public var sources: [SourceShare]
    public var mediaItems: Int
    public var finished: Int
    public var abandoned: Int
    public var longestFocus: LogEntry?
    public var longestFocusMinutes: Double

    public var total: Double { activeMedia + backgroundMedia + focus + other }
    public var topSource: SourceShare? { sources.first }
    public var isEmpty: Bool { total <= 0 }
}

public enum InsightsBuilder {
    /// The seven days ending on `today`, each entry clipped to the days it covers.
    public static func week(ending today: Day, entries: [LogEntry], now: Date, calendar: Calendar) -> WeekInsights {
        var active = 0.0, background = 0.0, focus = 0.0, other = 0.0
        var bySource: [MediaSource: Double] = [:]
        var items = 0, finished = 0, abandoned = 0, days = 0
        var longest: LogEntry?
        var longestMinutes = 0.0
        var counted = Set<UUID>()

        for offset in stride(from: -6, through: 0, by: 1) {
            let day = today.adding(days: offset, calendar: calendar)
            let list = DayTimeline.entries(on: day, from: entries, now: now, calendar: calendar)
                .filter { !$0.isPending }
            if !list.isEmpty { days += 1 }
            for e in list {
                let len = DayTimeline.clippedMinutes(e, day: day, now: now, calendar: calendar)
                switch e.category {
                case .media: active += len
                case .mediaBackground: background += len
                case .focus: focus += len
                default: other += len
                }
                if let s = e.source { bySource[s, default: 0] += len }
                guard counted.insert(e.id).inserted else { continue }
                if e.source != nil {
                    items += e.mediaItemCount
                    if let d = e.durationMs, d > 0 {
                        let p = Double(e.consumedMs ?? 0) / Double(d)
                        if p >= 0.95 { finished += 1 } else if p < 0.5 { abandoned += 1 }
                    }
                }
                if e.category == .focus {
                    let full = DayTimeline.lengthMinutes(e, now: now)
                    if full > longestMinutes { longestMinutes = full; longest = e }
                }
            }
        }
        let sources = bySource
            .map { SourceShare(source: $0.key, minutes: $0.value) }
            .sorted { $0.minutes != $1.minutes ? $0.minutes > $1.minutes : $0.source.rawValue < $1.source.rawValue }
        return WeekInsights(dayCount: days, activeMedia: active, backgroundMedia: background, focus: focus,
                            other: other, sources: sources, mediaItems: items, finished: finished,
                            abandoned: abandoned, longestFocus: longest, longestFocusMinutes: longestMinutes)
    }
}

/// Archive heatmap and "on this day".
public enum ArchiveMath {
    public struct MonthGrid: Sendable {
        public var month: Day
        /// Empty cells before the 1st in a Monday-first grid.
        public var leadingBlanks: Int
        public var days: [Day]
    }

    public static func monthGrid(containing day: Day, calendar: Calendar) -> MonthGrid {
        let first = day.firstOfMonth
        let count = first.daysInMonth(calendar)
        let days = (1 ... count).map { Day(year: first.year, month: first.month, day: $0) }
        return MonthGrid(month: first, leadingBlanks: first.mondayIndex(calendar), days: days)
    }

    /// 0…1 — how much of the day was captured (16 waking hours = full), or the sample history value.
    public static func fill(for day: Day, snapshot: RecallData, now: Date, calendar: Calendar) -> Double {
        let list = DayTimeline.entries(on: day, from: snapshot.entries, now: now, calendar: calendar)
            .filter { !$0.isPending }
        let isToday = day.contains(now, calendar: calendar)
        if !isToday, let h = snapshot.history[day.key] { return h }
        guard !list.isEmpty else { return 0 }
        let minutes = list.reduce(0) { $0 + DayTimeline.clippedMinutes($1, day: day, now: now, calendar: calendar) }
        return min(1, max(0, minutes / 960))
    }

    /// Heat bucket 0…4.
    public static func level(_ fill: Double) -> Int {
        min(4, max(0, Int((fill * 5).rounded(.down))))
    }

    public struct OnThisDay: Sendable {
        public var day: Day
        public var text: String
    }

    /// A sentence about the same date a year ago, if anything was kept.
    public static func onThisDay(today: Day, entries: [LogEntry], now: Date, calendar: Calendar) -> OnThisDay? {
        let day = today.yearEarlier(calendar)
        let list = DayTimeline.entries(on: day, from: entries, now: now, calendar: calendar).filter { !$0.isPending }
        guard !list.isEmpty else { return nil }
        var placeCounts: [String: Int] = [:]
        for e in list { if let p = e.place { placeCounts[p, default: 0] += 1 } }
        let place = placeCounts.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key
        let media = list.filter { $0.category.isMedia }
        let mediaCount = media.reduce(0) { $0 + $1.mediaItemCount }
        let shortVideo = media.filter { $0.source == .tiktok }.reduce(0) { $0 + $1.mediaItemCount }
        let moment = list.first { $0.kind == .moment && $0.category != .sleep }
        let steps = list.compactMap(\.meta).first { $0.contains("steps") }

        var parts: [String] = []
        if let place = place { parts.append("You were in \(place).") }
        if let moment = moment { parts.append("\(moment.title).") }
        let aside = shortVideo > 0 && shortVideo < mediaCount ? "\(spelled(shortVideo)) of them short video" : nil
        if mediaCount > 0 {
            var sentence = "Logged \(mediaCount) media"
            if let steps = steps {
                sentence += aside.map { " — \($0) —" } ?? ""
                sentence += " and walked \(steps)."
            } else {
                sentence += aside.map { " — \($0)." } ?? "."
            }
            parts.append(sentence)
        } else if let steps = steps {
            parts.append("Walked \(steps).")
        }
        return OnThisDay(day: day, text: parts.joined(separator: " "))
    }

    static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                     "eleven", "twelve"]
        return n < words.count ? words[n] : "\(n)"
    }
}
