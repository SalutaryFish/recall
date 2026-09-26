import Foundation

/// The prototype's formatters (`hhmm`, `dur`, `clock`, date labels), with fixed
/// English tables so output is identical on every OS and ICU version.
public enum Fmt {
    static let weekdaysShort = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    static let weekdaysLong = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let monthsLong = ["January", "February", "March", "April", "May", "June", "July",
                             "August", "September", "October", "November", "December"]

    static func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

    /// "07:10" from minutes after midnight (wraps at 24h like the prototype).
    public static func hhmm(minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return "\(pad2(m / 60)):\(pad2(m % 60))"
    }

    /// "07:10" for a date, in the calendar's time zone.
    public static func hhmm(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return "\(pad2(c.hour ?? 0)):\(pad2(c.minute ?? 0))"
    }

    /// The prototype's `dur`: "45m", "2h", "1h05m".
    public static func duration(minutes: Double) -> String {
        let m = max(0, Int(minutes.rounded()))
        let h = m / 60, r = m % 60
        if h == 0 { return "\(r)m" }
        return r == 0 ? "\(h)h" : "\(h)h\(pad2(r))m"
    }

    public static func duration(_ interval: TimeInterval) -> String {
        duration(minutes: interval / 60)
    }

    /// The prototype's `clock`: "0:00:00" / "1:24:06".
    public static func clock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval.rounded(.down)))
        return "\(s / 3600):\(pad2(s % 3600 / 60)):\(pad2(s % 60))"
    }

    /// "45s" for a session item.
    public static func seconds(ms: Int?) -> String {
        "\(Int((Double(ms ?? 0) / 1000).rounded()))s"
    }

    /// "FRI · 26 SEP 2026"
    public static func dateLabel(_ day: Day, calendar: Calendar) -> String {
        let wd = weekdaysShort[(day.weekday(calendar) - 1 + 7) % 7]
        return "\(wd) · \(pad2(day.day)) \(monthsShort[day.month - 1].uppercased()) \(day.year)"
    }

    /// "Today", "Yesterday", "Tomorrow", else the weekday ("Wednesday").
    public static func dayTitle(_ day: Day, today: Day, calendar: Calendar) -> String {
        switch today.days(to: day, calendar: calendar) {
        case 0: return "Today"
        case -1: return "Yesterday"
        case 1: return "Tomorrow"
        default: return weekdaysLong[(day.weekday(calendar) - 1 + 7) % 7]
        }
    }

    /// "SEPTEMBER 2026"
    public static func monthYear(_ day: Day) -> String {
        "\(monthsLong[day.month - 1].uppercased()) \(day.year)"
    }

    /// "26 Sep"
    public static func shortDate(_ day: Day) -> String {
        "\(pad2(day.day)) \(monthsShort[day.month - 1])"
    }

    /// "FRI 26 SEP" (heatmap popover)
    public static func compactDate(_ day: Day, calendar: Calendar) -> String {
        let wd = weekdaysShort[(day.weekday(calendar) - 1 + 7) % 7]
        return "\(wd) \(day.day) \(monthsShort[day.month - 1].uppercased())"
    }

    /// "26 SEPTEMBER" (Insights kicker)
    public static func dayMonth(_ day: Day) -> String {
        "\(day.day) \(monthsLong[day.month - 1].uppercased())"
    }

    /// "1,234"
    public static func grouped(_ n: Int) -> String {
        let digits = String(abs(n))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return n < 0 ? "-" + out : out
    }
}
