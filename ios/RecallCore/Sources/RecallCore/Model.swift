import Foundation

// The native schema from Recall-UX.md §8, with absolute dates (ISO 8601 on disk)
// instead of the prototype's minutes-from-midnight.

public enum EntryKind: String, Codable, Sendable, CaseIterable {
    case block, media, moment, session
}

/// Drives the ribbon tone. `mediaBackground` is serialised as the prototype's "mediabg".
public enum EntryCategory: String, Codable, Sendable, CaseIterable {
    case sleep, life, focus, social, media
    case mediaBackground = "mediabg"

    public var isMedia: Bool { self == .media || self == .mediaBackground }
}

public enum MediaSource: String, Codable, Sendable, CaseIterable {
    case youtube, tiktok, spotify, netflix, podcast, kindle, web

    /// Upper-case label used in mono metadata lines ("YOUTUBE · NetworkChuck").
    public var label: String { rawValue.uppercased() }

    /// Placeholder thumbnail glyph. U+FE0E keeps ▶ from rendering as an emoji.
    public var glyph: String {
        switch self {
        case .youtube: return "\u{25B6}\u{FE0E}"
        case .tiktok: return "\u{25C6}\u{FE0E}"
        case .spotify: return "\u{266B}\u{FE0E}"
        case .netflix: return "\u{25A4}\u{FE0E}"
        case .podcast: return "\u{25C9}\u{FE0E}"
        case .kindle: return "\u{25AD}\u{FE0E}"
        case .web: return "\u{2317}\u{FE0E}"
        }
    }
}

public enum Attention: String, Codable, Sendable, CaseIterable {
    case active, background
}

public enum Origin: String, Codable, Sendable {
    case manual, share, auto
}

public enum EntryStatus: String, Codable, Sendable {
    case confirmed, pending
}

/// One item inside a session card (a single short video in "Scroll — TikTok · 23 items").
public struct SessionItem: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var source: MediaSource?
    public var durationMs: Int?
    public var consumedMs: Int?

    public init(id: UUID = UUID(), title: String, source: MediaSource? = nil,
                durationMs: Int? = nil, consumedMs: Int? = nil) {
        self.id = id
        self.title = title
        self.source = source
        self.durationMs = durationMs
        self.consumedMs = consumedMs
    }
}

public struct LogEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: EntryKind
    public var start: Date
    /// `nil` while the entry is live.
    public var end: Date?
    public var title: String
    public var category: EntryCategory
    public var tags: [String]
    public var place: String?
    public var people: [String]?

    // media
    public var source: MediaSource?
    public var creator: String?
    /// Length of the work itself.
    public var durationMs: Int?
    /// How much of it was actually taken in.
    public var consumedMs: Int?
    public var attention: Attention?
    public var items: [SessionItem]?

    // provenance
    public var origin: Origin
    public var confidence: Double?
    public var status: EntryStatus

    public var note: String?
    /// Secondary line for moments ("slept 7h12m · 64bpm resting").
    public var meta: String?
    /// File names of photos stored next to the archive.
    public var photos: [String]?
    public var url: URL?
    /// Seeded demo data (and simulated auto-captures). Cleared by "Clear sample data".
    public var sample: Bool?

    public init(id: UUID = UUID(), kind: EntryKind = .block, start: Date, end: Date?,
                title: String, category: EntryCategory = .life, tags: [String] = [],
                place: String? = nil, people: [String]? = nil,
                source: MediaSource? = nil, creator: String? = nil,
                durationMs: Int? = nil, consumedMs: Int? = nil,
                attention: Attention? = nil, items: [SessionItem]? = nil,
                origin: Origin = .manual, confidence: Double? = nil,
                status: EntryStatus = .confirmed, note: String? = nil, meta: String? = nil,
                photos: [String]? = nil, url: URL? = nil, sample: Bool? = nil) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.title = title
        self.category = category
        self.tags = tags
        self.place = place
        self.people = people
        self.source = source
        self.creator = creator
        self.durationMs = durationMs
        self.consumedMs = consumedMs
        self.attention = attention
        self.items = items
        self.origin = origin
        self.confidence = confidence
        self.status = status
        self.note = note
        self.meta = meta
        self.photos = photos
        self.url = url
        self.sample = sample
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, start, end, title, category, tags, place, people, source, creator
        case durationMs, consumedMs, attention, items, origin, confidence, status
        case note, meta, photos, url, sample
    }

    /// Lenient decoding: unknown enum values and missing optional fields never
    /// make the whole archive unreadable.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decodeIfPresent(Date.self, forKey: .end)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        kind = (try? c.decodeIfPresent(EntryKind.self, forKey: .kind)) ?? .block
        category = (try? c.decodeIfPresent(EntryCategory.self, forKey: .category)) ?? .life
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        place = try? c.decodeIfPresent(String.self, forKey: .place)
        people = try? c.decodeIfPresent([String].self, forKey: .people)
        source = try? c.decodeIfPresent(MediaSource.self, forKey: .source)
        creator = try? c.decodeIfPresent(String.self, forKey: .creator)
        durationMs = try? c.decodeIfPresent(Int.self, forKey: .durationMs)
        consumedMs = try? c.decodeIfPresent(Int.self, forKey: .consumedMs)
        attention = try? c.decodeIfPresent(Attention.self, forKey: .attention)
        items = try? c.decodeIfPresent([SessionItem].self, forKey: .items)
        origin = (try? c.decodeIfPresent(Origin.self, forKey: .origin)) ?? .manual
        confidence = try? c.decodeIfPresent(Double.self, forKey: .confidence)
        status = (try? c.decodeIfPresent(EntryStatus.self, forKey: .status)) ?? .confirmed
        note = try? c.decodeIfPresent(String.self, forKey: .note)
        meta = try? c.decodeIfPresent(String.self, forKey: .meta)
        photos = try? c.decodeIfPresent([String].self, forKey: .photos)
        url = try? c.decodeIfPresent(URL.self, forKey: .url)
        sample = try? c.decodeIfPresent(Bool.self, forKey: .sample)
    }

    public var isLive: Bool { end == nil }
    public var isPending: Bool { status == .pending }
    public var isSample: Bool { sample == true }
    public var isBackground: Bool { attention == .background }

    /// 0–100 share of the work that was consumed, when the length of the work is known.
    public var completionPercent: Int? {
        guard let d = durationMs, d > 0 else { return nil }
        return min(100, max(0, Int((Double(consumedMs ?? 0) / Double(d) * 100).rounded())))
    }

    /// Number of media items this entry stands for (a session counts its children).
    public var mediaItemCount: Int {
        kind == .session ? (items?.count ?? 0) : 1
    }
}

public struct Frequent: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public var glyph: String
    public var name: String
    public var category: EntryCategory
    public var uses: Int
    /// Hours of the day at which this is usually done; ranks it up at those hours.
    public var hours: [Int]
    /// The part of `uses` that came from sample data, removed by "Clear sample data".
    public var sampleUses: Int?

    public init(glyph: String, name: String, category: EntryCategory, uses: Int, hours: [Int],
                sampleUses: Int? = nil) {
        self.glyph = glyph
        self.name = name
        self.category = category
        self.uses = uses
        self.hours = hours
        self.sampleUses = sampleUses
    }
}

public enum Density: Int, Codable, Sendable, CaseIterable {
    case transcript = 0, proportional = 1, ribbon = 2

    public var label: String {
        switch self {
        case .transcript: return "TRANSCRIPT"
        case .proportional: return "PROPORTIONAL"
        case .ribbon: return "RIBBON"
        }
    }

    public var next: Density? { Density(rawValue: rawValue + 1) }
    public var previous: Density? { Density(rawValue: rawValue - 1) }
    /// Tap on the density chip cycles through all three.
    public var cycled: Density { Density(rawValue: (rawValue + 1) % 3) ?? .transcript }
}

public enum ThemePreference: String, Codable, Sendable, CaseIterable {
    case auto, light, dark
}

public struct Counters: Codable, Hashable, Sendable {
    /// Media saved through capture.
    public var mediaSaved: Int
    /// "Lived-in" offsets that come with the sample data (the prototype's +410 days, +3,120 hours).
    public var sampleMedia: Int
    public var sampleDays: Int
    public var sampleHours: Int

    public init(mediaSaved: Int = 0, sampleMedia: Int = 0, sampleDays: Int = 0, sampleHours: Int = 0) {
        self.mediaSaved = mediaSaved
        self.sampleMedia = sampleMedia
        self.sampleDays = sampleDays
        self.sampleHours = sampleHours
    }
}

/// Everything Recall persists, as one value.
public struct RecallData: Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var entries: [LogEntry]
    /// Heatmap fill (0–1) for days that have no detail kept (sample history), keyed "yyyy-MM-dd".
    public var history: [String: Double]
    public var frequents: [Frequent]
    public var density: Density
    public var theme: ThemePreference
    public var counters: Counters
    /// Prototype-style simulated auto-capture (pending detections every 22–42 s).
    public var simulateAutoCapture: Bool
    public var hasSamples: Bool
    public var hintsShown: Int

    public init(version: Int = RecallData.currentVersion, entries: [LogEntry] = [],
                history: [String: Double] = [:], frequents: [Frequent] = RecallData.defaultFrequents,
                density: Density = .transcript, theme: ThemePreference = .auto,
                counters: Counters = Counters(), simulateAutoCapture: Bool = false,
                hasSamples: Bool = false, hintsShown: Int = 0) {
        self.version = version
        self.entries = entries
        self.history = history
        self.frequents = frequents
        self.density = density
        self.theme = theme
        self.counters = counters
        self.simulateAutoCapture = simulateAutoCapture
        self.hasSamples = hasSamples
        self.hintsShown = hintsShown
    }

    enum CodingKeys: String, CodingKey {
        case version, entries, history, frequents, density, theme, counters
        case simulateAutoCapture, hasSamples, hintsShown
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? RecallData.currentVersion
        entries = try c.decodeIfPresent([LogEntry].self, forKey: .entries) ?? []
        history = (try? c.decodeIfPresent([String: Double].self, forKey: .history)) ?? [:]
        frequents = (try? c.decodeIfPresent([Frequent].self, forKey: .frequents)) ?? RecallData.defaultFrequents
        density = (try? c.decodeIfPresent(Density.self, forKey: .density)) ?? .transcript
        theme = (try? c.decodeIfPresent(ThemePreference.self, forKey: .theme)) ?? .auto
        counters = (try? c.decodeIfPresent(Counters.self, forKey: .counters)) ?? Counters()
        simulateAutoCapture = (try? c.decodeIfPresent(Bool.self, forKey: .simulateAutoCapture)) ?? false
        hasSamples = (try? c.decodeIfPresent(Bool.self, forKey: .hasSamples)) ?? false
        hintsShown = (try? c.decodeIfPresent(Int.self, forKey: .hintsShown)) ?? 0
    }

    /// The eight frequents from the prototype, with no usage yet.
    public static let defaultFrequents: [Frequent] = [
        Frequent(glyph: "\u{2615}", name: "Coffee", category: .life, uses: 0, hours: [7, 8, 9, 14]),
        Frequent(glyph: "\u{1F4BB}", name: "Deep work", category: .focus, uses: 0, hours: [9, 10, 11, 14, 15, 16]),
        Frequent(glyph: "\u{1F3CB}\u{FE0F}", name: "Gym", category: .life, uses: 0, hours: [7, 8, 17, 18, 19]),
        Frequent(glyph: "\u{1F6B6}", name: "Walk", category: .life, uses: 0, hours: [12, 13, 17, 18]),
        Frequent(glyph: "\u{1F373}", name: "Cook", category: .social, uses: 0, hours: [12, 18, 19, 20]),
        Frequent(glyph: "\u{1F634}", name: "Sleep", category: .sleep, uses: 0, hours: [22, 23, 0]),
        Frequent(glyph: "\u{25B6}\u{FE0E}", name: "YouTube", category: .media, uses: 0, hours: [8, 12, 21, 22]),
        Frequent(glyph: "\u{1F4D6}", name: "Read", category: .life, uses: 0, hours: [8, 21, 22, 23]),
    ]
}
