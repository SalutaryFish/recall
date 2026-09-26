import Foundation

/// ISO 8601 timestamps without `ISO8601DateFormatter`, which needs system time zone
/// data (absent on NixOS, where the Linux tests run) and is slow on every platform.
/// Writes UTC with whole seconds; reads "YYYY-MM-DDTHH:MM:SS[.fff][Z|±HH:MM|±HHMM]".
enum ISO8601 {
    static func string(from date: Date) -> String {
        let t = Int64(date.timeIntervalSince1970.rounded(.down))
        var days = t / 86_400
        var secs = t % 86_400
        if secs < 0 {
            secs += 86_400
            days -= 1
        }
        let (y, m, d) = civil(fromDays: days)
        return "\(pad(y, 4))-\(pad(m, 2))-\(pad(d, 2))T\(pad(secs / 3600, 2)):\(pad(secs % 3600 / 60, 2)):\(pad(secs % 60, 2))Z"
    }

    static func date(from string: String) -> Date? {
        let parts = string.split(separator: "T", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let ymd = parts[0].split(separator: "-").compactMap { Int64($0) }
        guard ymd.count == 3 else { return nil }

        var time = Substring(parts[1])
        var offset: Int64 = 0
        if time.hasSuffix("Z") {
            time = time.dropLast()
        } else if let signIndex = time.lastIndex(where: { $0 == "+" || $0 == "-" }) {
            let sign: Int64 = time[signIndex] == "-" ? -1 : 1
            let zone = time[time.index(after: signIndex)...].filter { $0 != ":" }
            guard zone.count == 4, let hh = Int64(zone.prefix(2)), let mm = Int64(zone.suffix(2)) else { return nil }
            offset = sign * (hh * 3600 + mm * 60)
            time = time[..<signIndex]
        }
        var fraction = 0.0
        if let dot = time.firstIndex(of: ".") {
            fraction = Double("0" + time[dot...]) ?? 0
            time = time[..<dot]
        }
        let hms = time.split(separator: ":").compactMap { Int64($0) }
        guard hms.count == 3 else { return nil }
        let days = days(fromCivil: ymd[0], ymd[1], ymd[2])
        let seconds = days * 86_400 + hms[0] * 3600 + hms[1] * 60 + hms[2] - offset
        return Date(timeIntervalSince1970: Double(seconds) + fraction)
    }

    /// Howard Hinnant's days-from-civil / civil-from-days (proleptic Gregorian, UTC).
    static func days(fromCivil year: Int64, _ month: Int64, _ day: Int64) -> Int64 {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civil(fromDays days: Int64) -> (Int64, Int64, Int64) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (m <= 2 ? yoe + era * 400 + 1 : yoe + era * 400, m, d)
    }

    private static func pad(_ n: Int64, _ width: Int) -> String {
        let s = String(n)
        return s.count >= width ? s : String(repeating: "0", count: width - s.count) + s
    }
}
