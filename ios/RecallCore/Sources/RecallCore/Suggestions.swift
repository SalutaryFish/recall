import Foundation

public struct Suggestion: Hashable, Sendable, Identifiable {
    public enum Kind: String, Sendable { case block = "BLOCK", place = "PLACE" }
    public var kind: Kind
    public var text: String
    public var uses: Int
    public var id: String { kind.rawValue + text }
}

/// Frequents ranking, autocomplete and archive search.
public enum Suggestions {
    /// Frequents weighted toward the current hour, then by use (prototype `topFrequents`).
    public static func topFrequents(_ frequents: [Frequent], hour: Int, count: Int) -> [Frequent] {
        let scored = frequents.enumerated().map { (i, f) in
            (f, (f.hours.contains(hour) ? 1000 : 0) + f.uses, i)
        }
        return scored
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }
            .prefix(count)
            .map { $0.0 }
    }

    /// Titles the user has logged, most used first (moments excluded).
    public static func historyTitles(_ entries: [LogEntry], hour: Int? = nil,
                                     calendar: Calendar) -> [(title: String, count: Int)] {
        var counts: [String: Int] = [:]
        var score: [String: Int] = [:]
        for e in entries where e.kind != .moment && !e.isPending {
            counts[e.title, default: 0] += 1
            var s = 1
            if let hour = hour, calendar.component(.hour, from: e.start) == hour { s += 1 }
            score[e.title, default: 0] += s
        }
        return counts.keys
            .sorted { (score[$0] ?? 0, $1) > (score[$1] ?? 0, $0) }
            .map { ($0, counts[$0] ?? 0) }
    }

    /// Quick-add autocomplete: up to three blocks and one place (§6.3), ranked by
    /// frequency with a bonus for things usually done at this hour.
    public static func autocomplete(_ query: String, entries: [LogEntry], hour: Int,
                                    calendar: Calendar) -> [Suggestion] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let blocks = historyTitles(entries, hour: hour, calendar: calendar)
            .filter { $0.title.lowercased().contains(q) }
            .prefix(3)
            .map { Suggestion(kind: .block, text: $0.title, uses: $0.count) }
        var seen = Set<String>()
        let places = entries.compactMap(\.place)
            .filter { seen.insert($0).inserted && $0.lowercased().contains(q) }
            .prefix(1)
            .map { Suggestion(kind: .place, text: $0, uses: 0) }
        return Array(blocks) + Array(places)
    }

    /// Archive search over title, creator, place and tags; newest first, at most eight.
    public static func search(_ query: String, in entries: [LogEntry]) -> [LogEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        return entries
            .filter { e in
                ([e.title, e.creator ?? "", e.place ?? ""] + e.tags)
                    .joined(separator: " ")
                    .lowercased()
                    .contains(q)
            }
            .sorted { $0.start > $1.start }
            .prefix(8)
            .map { $0 }
    }
}
