import Foundation

/// One row of the Today transcript: an entry, or an untracked gap between entries.
public enum TimelineRow: Identifiable, Hashable, Sendable {
    case entry(LogEntry)
    case gap(start: Date, end: Date)

    public var id: String {
        switch self {
        case .entry(let e): return e.id.uuidString
        case .gap(let s, _): return "gap-\(Int(s.timeIntervalSince1970))"
        }
    }
}

public struct DayStats: Equatable, Sendable {
    public var trackedMinutes: Double
    public var mediaAttentionMinutes: Double
    public var mediaItems: Int
    public var entryCount: Int
}

public struct RibbonSegment: Hashable, Sendable {
    /// 0…1 across the day.
    public var from: Double
    public var to: Double
    public var category: EntryCategory
}

public enum DayTimeline {
    /// Gaps shorter than this are not worth a row (prototype: 20 min).
    public static let minimumGap: TimeInterval = 20 * 60

    public static func effectiveEnd(_ e: LogEntry, now: Date) -> Date {
        e.end ?? max(now, e.start)
    }

    /// The prototype's `lengthOf`: at least one minute.
    public static func lengthMinutes(_ e: LogEntry, now: Date) -> Double {
        max(1, effectiveEnd(e, now: now).timeIntervalSince(e.start) / 60)
    }

    /// Length of the part of `e` that falls inside `day`.
    public static func clippedMinutes(_ e: LogEntry, day: Day, now: Date, calendar: Calendar) -> Double {
        let s = max(e.start, day.start(calendar))
        let en = min(effectiveEnd(e, now: now), day.end(calendar))
        return max(0, en.timeIntervalSince(s) / 60)
    }

    /// Entries that overlap `day`, oldest first. A midnight-crossing entry appears on both days.
    public static func entries(on day: Day, from all: [LogEntry], now: Date, calendar: Calendar) -> [LogEntry] {
        let s = day.start(calendar), e = day.end(calendar)
        return all
            .filter { $0.start < e && effectiveEnd($0, now: now) > s }
            .sorted { $0.start == $1.start ? $0.id.uuidString < $1.id.uuidString : $0.start < $1.start }
    }

    /// Entries plus hatched gap rows (≥ 20 min), and a trailing gap up to now on today
    /// when nothing is live — "a trailing gap up to now is just as real as one in the middle".
    public static func rows(for dayEntries: [LogEntry], day: Day, now: Date, calendar: Calendar) -> [TimelineRow] {
        var rows: [TimelineRow] = []
        let dayStart = day.start(calendar), dayEnd = day.end(calendar)
        var prevEnd: Date?
        for e in dayEntries {
            if let p = prevEnd, e.start.timeIntervalSince(p) >= minimumGap {
                rows.append(.gap(start: p, end: e.start))
            }
            rows.append(.entry(e))
            let end = min(effectiveEnd(e, now: now), dayEnd)
            prevEnd = max(prevEnd ?? end, end)
        }
        let isToday = day.contains(now, calendar: calendar)
        let hasLive = dayEntries.contains { $0.isLive }
        if isToday, !hasLive, let p = prevEnd, p >= dayStart, now.timeIntervalSince(p) >= minimumGap {
            rows.append(.gap(start: p, end: now))
        }
        return rows
    }

    /// Header stats: time tracked, media attention (active only), media item count.
    public static func stats(for dayEntries: [LogEntry], day: Day, now: Date, calendar: Calendar) -> DayStats {
        var tracked = 0.0, active = 0.0, items = 0
        for e in dayEntries {
            let len = clippedMinutes(e, day: day, now: now, calendar: calendar)
            tracked += len
            if e.category.isMedia {
                items += e.mediaItemCount
                if !e.isBackground { active += len }
            }
        }
        return DayStats(trackedMinutes: tracked, mediaAttentionMinutes: active,
                        mediaItems: items, entryCount: dayEntries.count)
    }

    /// Coloured segments for the 24h ribbon; untracked time is left out so the hatch shows through.
    public static func ribbon(for dayEntries: [LogEntry], day: Day, now: Date, calendar: Calendar) -> [RibbonSegment] {
        let start = day.start(calendar)
        let total = max(1, day.end(calendar).timeIntervalSince(start))
        var cursor = 0.0
        var out: [RibbonSegment] = []
        for e in dayEntries {
            let from = max(0, min(1, e.start.timeIntervalSince(start) / total))
            let to = max(0, min(1, effectiveEnd(e, now: now).timeIntervalSince(start) / total))
            let clippedFrom = max(from, cursor)
            if to > clippedFrom {
                out.append(RibbonSegment(from: clippedFrom, to: to, category: e.category))
            }
            cursor = max(cursor, to)
        }
        return out
    }

    /// Row height per density (§2.3). `nil` = natural height (transcript).
    /// Proportional is log-compressed with a 44 pt floor so a two-minute entry stays tappable.
    public static func rowHeight(minutes: Double, density: Density) -> Double? {
        switch density {
        case .transcript:
            return nil
        case .proportional:
            return min(300, max(44, 44 + 34 * log2(1 + minutes / 10))).rounded()
        case .ribbon:
            return min(900, max(44, minutes * 1.5)).rounded()
        }
    }

    /// Long-press re-time (G5): vertical drag in points → whole minutes, snapped to 5.
    public static func retimeDelta(dragPoints: Double, density: Density) -> Int {
        let minutesPerPoint = density == .ribbon ? 1 / 1.5 : 0.75
        return Int((dragPoints * minutesPerPoint / 5).rounded()) * 5
    }

    /// Fraction (0…1) of the day at `date`.
    public static func fraction(of date: Date, in day: Day, calendar: Calendar) -> Double {
        let start = day.start(calendar)
        let total = max(1, day.end(calendar).timeIntervalSince(start))
        return max(0, min(1, date.timeIntervalSince(start) / total))
    }

    /// The date at a fraction of the day (ribbon scrub).
    public static func date(atFraction f: Double, in day: Day, calendar: Calendar) -> Date {
        let start = day.start(calendar)
        let total = day.end(calendar).timeIntervalSince(start)
        return start.addingTimeInterval(max(0, min(1, f)) * total)
    }

    /// The last entry starting at or before `date` (what the ribbon scrub jumps to).
    public static func entry(atOrBefore date: Date, in dayEntries: [LogEntry]) -> LogEntry? {
        dayEntries.last { $0.start <= date } ?? dayEntries.first
    }
}
