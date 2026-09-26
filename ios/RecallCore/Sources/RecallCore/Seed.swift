import Foundation

/// The prototype's LCG (`rng` in Recall.proto.html), so seeded values match it exactly.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt32

    public init(seed: UInt32) { state = seed }

    /// 0 ..< 1
    public mutating func nextUnit() -> Double {
        state = state &* 1_664_525 &+ 1_013_904_223
        return Double(state) / 4_294_967_296
    }

    public mutating func next() -> UInt64 {
        let hi = UInt64(UInt32(nextUnit() * 4_294_967_296))
        let lo = UInt64(UInt32(nextUnit() * 4_294_967_296))
        return hi << 32 | lo
    }
}

/// Sample data: today so far (absolute clock times, only what the clock has reached),
/// two full past days, ten weeks of heatmap history and a year-ago day in Lisbon.
/// Every entry is tagged `sample` so it can be cleared for real use.
public enum Seed {
    struct Template {
        var start: Int
        var end: Int
        var kind: EntryKind = .block
        var title: String
        var category: EntryCategory = .life
        var tags: [String] = []
        var place: String?
        var source: MediaSource?
        var creator: String?
        var durationMs: Int?
        var consumedMs: Int?
        var attention: Attention?
        var origin: Origin = .manual
        var meta: String?
        var itemTitles: [String]?
    }

    static let today: [Template] = [
        Template(start: 430, end: 445, kind: .moment, title: "Woke up", category: .sleep,
                 meta: "slept 7h12m · 64bpm resting"),
        Template(start: 445, end: 520, title: "Morning routine", tags: ["coffee", "shower", "read"], place: "Home"),
        Template(start: 520, end: 533, kind: .media, title: "How to build a Pi-hole DNS resolver", category: .media,
                 source: .youtube, creator: "NetworkChuck", durationMs: 761_000, consumedMs: 482_000,
                 attention: .active, origin: .share),
        Template(start: 560, end: 700, title: "Deep work — Design", category: .focus,
                 tags: ["recall", "figma"], place: "Home studio"),
        Template(start: 700, end: 742, kind: .session, title: "Scroll — TikTok", category: .media,
                 source: .tiktok, attention: .active, origin: .auto,
                 itemTitles: ["3 underrated Lisbon viewpoints", "how to fold a fitted sheet",
                              "espresso puck prep, 40s", "a very small dog", "brutalist london walkthrough",
                              "why your sourdough is flat", "ranking every ikea desk"]),
        Template(start: 742, end: 800, title: "Lunch", category: .social, tags: ["leftovers"], place: "Kitchen"),
        Template(start: 800, end: 845, kind: .media, title: "Hyperpop for Cooking", category: .mediaBackground,
                 source: .spotify, creator: "playlist · 23 tracks", durationMs: 2_700_000, consumedMs: 2_700_000,
                 attention: .background, origin: .auto),
        Template(start: 935, end: 989, kind: .media, title: "The Rest Is History — Ep. 412", category: .media,
                 source: .podcast, creator: "Sandbrook & Holland", durationMs: 3_300_000, consumedMs: 3_240_000,
                 attention: .active, origin: .auto),
        Template(start: 989, end: 1061, title: "Walk — Regent's Canal", tags: ["walk"], place: "Hackney"),
    ]

    static let pastDay: [Template] = [
        Template(start: 455, end: 470, kind: .moment, title: "Woke up", category: .sleep, meta: "slept 6h48m"),
        Template(start: 470, end: 530, title: "Morning routine", tags: ["coffee", "read"]),
        Template(start: 530, end: 545, kind: .media, title: "Why Cities Are Getting Quieter", category: .media,
                 source: .youtube, creator: "Not Just Bikes", durationMs: 1_020_000, consumedMs: 900_000,
                 attention: .active),
        Template(start: 560, end: 740, title: "Deep work — Recall spec", category: .focus, place: "Home studio"),
        Template(start: 740, end: 790, title: "Lunch", category: .social, place: "Towpath"),
        Template(start: 790, end: 880, kind: .media, title: "Ambient Works Vol II", category: .mediaBackground,
                 source: .spotify, creator: "Aphex Twin", durationMs: 5_400_000, consumedMs: 5_400_000,
                 attention: .background),
        Template(start: 880, end: 1010, title: "Gym — push day", place: "PureGym Shoreditch"),
        Template(start: 1050, end: 1100, kind: .session, title: "Scroll — TikTok", category: .media,
                 source: .tiktok, attention: .active,
                 itemTitles: ["knife skills, 30s", "a cat that yells", "lisbon tram at dawn",
                              "the worst kitchen renovation", "one-pan gnocchi"]),
        Template(start: 1170, end: 1270, kind: .media, title: "The Bear — S3E4", category: .media,
                 source: .netflix, creator: "FX", durationMs: 2_040_000, consumedMs: 2_040_000, attention: .active),
        Template(start: 1270, end: 1310, kind: .moment, title: "Read before bed", meta: "Piranesi · 22 pages"),
    ]

    static let yearAgo: [Template] = [
        Template(start: 490, end: 500, kind: .moment, title: "Woke up", category: .sleep, place: "Lisbon",
                 meta: "slept 8h02m · Alfama"),
        Template(start: 560, end: 700, title: "Walk — Alfama to Baixa", tags: ["walk"], place: "Lisbon",
                 meta: "14,203 steps"),
        Template(start: 760, end: 812, kind: .session, title: "Scroll — TikTok", category: .media,
                 place: "Lisbon", source: .tiktok, attention: .active,
                 itemTitles: ["3 underrated Lisbon viewpoints", "pastel de nata ranking", "tram 28, honestly",
                              "azulejo restoration", "fado in 40 seconds", "lisbon tram at dawn",
                              "where locals eat", "sintra day trip", "miradouro sunset timelapse"]),
        Template(start: 900, end: 918, kind: .media, title: "A Short History of Lisbon", category: .media,
                 place: "Lisbon", source: .youtube, creator: "Kings and Generals",
                 durationMs: 1_260_000, consumedMs: 1_080_000, attention: .active),
        Template(start: 1150, end: 1190, kind: .moment, title: "Sunset at Miradouro da Graça", place: "Lisbon"),
        Template(start: 1230, end: 1290, kind: .media, title: "Amália — Com Que Voz", category: .mediaBackground,
                 place: "Lisbon", source: .spotify, creator: "Amália Rodrigues",
                 durationMs: 3_600_000, consumedMs: 3_600_000, attention: .background),
    ]

    static let sampleFrequentUses: [String: Int] = [
        "Coffee": 142, "Deep work": 96, "Gym": 61, "Walk": 58,
        "Cook": 44, "Sleep": 40, "YouTube": 88, "Read": 33,
    ]

    public static func sampleSnapshot(now: Date, calendar: Calendar) -> RecallData {
        var rng = SeededRandom(seed: 20_260_923)
        var entries: [LogEntry] = []
        let todayDay = Day(now, calendar: calendar)
        let dayStart = todayDay.start(calendar)
        let nowMin = Int(now.timeIntervalSince(dayStart) / 60)

        // Today: only what the clock has actually reached.
        var lastEnd = 0
        for t in today where t.end <= nowMin {
            entries.append(make(t, on: todayDay, calendar: calendar, rng: &rng))
            lastEnd = max(lastEnd, t.end)
        }
        // Live — always present, never overlapping what came before.
        let liveStart = min(max(max(lastEnd, nowMin - 84), 0), max(0, nowMin - 1))
        entries.append(LogEntry(kind: .block, start: dayStart.addingTimeInterval(Double(liveStart) * 60), end: nil,
                                title: "Deep work — Design", category: .focus, tags: ["recall"],
                                place: "Home studio", sample: true))

        // Two past days; the second one shifted and missing a couple of blocks so the week isn't copy-pasted.
        for (variant, offset) in [-1, -2].enumerated() {
            let day = todayDay.adding(days: offset, calendar: calendar)
            let jitter = variant == 1 ? 18 : 0
            for (i, t) in pastDay.enumerated() {
                if variant == 1 && (i == 5 || i == 7) { continue }
                var shifted = t
                shifted.start += jitter
                shifted.end += jitter
                entries.append(make(shifted, on: day, calendar: calendar, rng: &rng))
            }
        }

        // A year ago, so "On this day" has something real to say.
        let lastYear = todayDay.yearEarlier(calendar)
        for t in yearAgo {
            entries.append(make(t, on: lastYear, calendar: calendar, rng: &rng))
        }

        // Heatmap history: fills for the ten weeks before the detailed days.
        var hist = SeededRandom(seed: 20_260_923)
        var history: [String: Double] = [:]
        for i in 3 ..< 70 {
            history[todayDay.adding(days: -i, calendar: calendar).key] = (hist.nextUnit() * 100).rounded() / 100
        }

        var frequents = RecallData.defaultFrequents
        for i in frequents.indices {
            let uses = sampleFrequentUses[frequents[i].name] ?? 0
            frequents[i].uses = uses
            frequents[i].sampleUses = uses
        }

        return RecallData(entries: entries, history: history, frequents: frequents,
                          counters: Counters(mediaSaved: 0, sampleMedia: 5_841, sampleDays: 410, sampleHours: 3_120),
                          simulateAutoCapture: true, hasSamples: true)
    }

    static func make(_ t: Template, on day: Day, calendar: Calendar, rng: inout SeededRandom) -> LogEntry {
        let start = day.start(calendar)
        let items = t.itemTitles.map { titles in
            titles.map { SessionItem(title: $0, source: t.source,
                                     durationMs: (35 + Int(rng.nextUnit() * 90)) * 1000,
                                     consumedMs: (20 + Int(rng.nextUnit() * 70)) * 1000) }
        }
        return LogEntry(kind: t.kind, start: start.addingTimeInterval(Double(t.start) * 60),
                        end: start.addingTimeInterval(Double(t.end) * 60), title: t.title, category: t.category,
                        tags: t.tags, place: t.place, source: t.source, creator: t.creator,
                        durationMs: t.durationMs, consumedMs: t.consumedMs, attention: t.attention, items: items,
                        origin: t.origin, status: .confirmed, meta: t.meta, sample: true)
    }
}
