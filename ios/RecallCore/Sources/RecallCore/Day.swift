import Foundation

/// A local calendar day. Everything that "belongs to a day" is computed by
/// intersecting absolute dates with `start ..< end` of one of these.
public struct Day: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// "yyyy-MM-dd", the key used for sample heatmap history.
    public init?(key: String) {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var key: String {
        "\(year)-\(Day.pad(month))-\(Day.pad(day))"
    }

    public func start(_ calendar: Calendar) -> Date {
        let comps = DateComponents(year: year, month: month, day: day)
        let date = calendar.date(from: comps) ?? Date(timeIntervalSince1970: 0)
        return calendar.startOfDay(for: date)
    }

    public func end(_ calendar: Calendar) -> Date {
        adding(days: 1, calendar: calendar).start(calendar)
    }

    /// Minutes in this day (1,440 except on DST changes).
    public func lengthInMinutes(_ calendar: Calendar) -> Double {
        end(calendar).timeIntervalSince(start(calendar)) / 60
    }

    public func adding(days: Int, calendar: Calendar) -> Day {
        let noon = calendar.date(byAdding: .hour, value: 12, to: start(calendar)) ?? start(calendar)
        let moved = calendar.date(byAdding: .day, value: days, to: noon) ?? noon
        return Day(moved, calendar: calendar)
    }

    /// Whole days from `self` to `other` (positive when `other` is later).
    public func days(to other: Day, calendar: Calendar) -> Int {
        let a = calendar.date(byAdding: .hour, value: 12, to: start(calendar)) ?? start(calendar)
        let b = calendar.date(byAdding: .hour, value: 12, to: other.start(calendar)) ?? other.start(calendar)
        return Int((b.timeIntervalSince(a) / 86_400).rounded())
    }

    /// 1 = Sunday … 7 = Saturday (Gregorian convention).
    public func weekday(_ calendar: Calendar) -> Int {
        calendar.component(.weekday, from: start(calendar))
    }

    /// 0 = Monday … 6 = Sunday, for Monday-first grids.
    public func mondayIndex(_ calendar: Calendar) -> Int {
        (weekday(calendar) + 5) % 7
    }

    public var firstOfMonth: Day { Day(year: year, month: month, day: 1) }

    public func daysInMonth(_ calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: start(calendar))?.count ?? 30
    }

    /// The same date a year earlier (29 Feb falls back to 28 Feb).
    public func yearEarlier(_ calendar: Calendar) -> Day {
        let date = calendar.date(byAdding: .year, value: -1, to: start(calendar)) ?? start(calendar)
        return Day(date, calendar: calendar)
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        date >= start(calendar) && date < end(calendar)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}
