import Foundation

/// A link resolved (or sampled) for "Save to Recall".
public struct SharedMedia: Hashable, Sendable {
    public var url: String
    public var title: String
    public var source: MediaSource
    public var creator: String?
    public var durationMs: Int?
    public var type: String
    public var extra: String?
    public var isSample: Bool

    public init(url: String, title: String, source: MediaSource, creator: String? = nil,
                durationMs: Int? = nil, type: String, extra: String? = nil, isSample: Bool = false) {
        self.url = url
        self.title = title
        self.source = source
        self.creator = creator
        self.durationMs = durationMs
        self.type = type
        self.extra = extra
        self.isSample = isSample
    }
}

public enum SharePool {
    /// The prototype's share pool (`SHARE_POOL`), used by "Try a sample".
    public static let samples: [SharedMedia] = [
        SharedMedia(url: "tiktok.com/@travelmaps/video/738…", title: "3 underrated Lisbon viewpoints",
                    source: .tiktok, creator: "@travelmaps", durationMs: 48_000,
                    type: "Short video · Travel", extra: "3 pins → Lisbon", isSample: true),
        SharedMedia(url: "youtube.com/watch?v=k2Hf…", title: "Every Bauhaus Chair, Ranked",
                    source: .youtube, creator: "Design Theory", durationMs: 1_284_000,
                    type: "Video essay · Design", extra: "8 chapters", isSample: true),
        SharedMedia(url: "open.spotify.com/album/3Qp…", title: "Selected Ambient Works 85–92",
                    source: .spotify, creator: "Aphex Twin", durationMs: 4_460_000,
                    type: "Album · 13 tracks", extra: "saved to library", isSample: true),
    ]
}

public enum SourceDetector {
    /// Media source from a link's host; anything unknown is `web`.
    public static func source(for url: URL) -> MediaSource {
        let host = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.host ?? "").lowercased()
        func matches(_ domains: [String]) -> Bool {
            domains.contains { host == $0 || host.hasSuffix("." + $0) }
        }
        if matches(["youtube.com", "youtu.be", "youtube-nocookie.com"]) { return .youtube }
        if matches(["tiktok.com"]) { return .tiktok }
        if matches(["spotify.com", "spotify.link"]) { return .spotify }
        if matches(["netflix.com"]) { return .netflix }
        if matches(["podcasts.apple.com", "overcast.fm", "pca.st", "pocketcasts.com", "castro.fm"]) { return .podcast }
        if matches(["read.amazon.com", "kindle.amazon.com"]) { return .kindle }
        return .web
    }

    public static func host(of url: URL) -> String {
        let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    public static func typeLabel(for source: MediaSource) -> String {
        switch source {
        case .youtube: return "Video · YouTube"
        case .tiktok: return "Short video · TikTok"
        case .spotify: return "Music · Spotify"
        case .netflix: return "Episode · Netflix"
        case .podcast: return "Podcast episode"
        case .kindle: return "Book · Kindle"
        case .web: return "Web page"
        }
    }
}

/// Simulated auto-ingest (§6.6): pending detections that ask "help or spam?".
public enum AutoIngest {
    struct Template {
        var title: String
        var source: MediaSource
        var creator: String?
        var durationMs: Int?
        var consumedMs: Int?
        var attention: Attention
        var kind: EntryKind = .media
        var titles: [String]?
    }

    static let pool: [Template] = [
        Template(title: "Kurzgesagt — The Last Human", source: .youtube, creator: "Kurzgesagt",
                 durationMs: 1_020_000, consumedMs: 1_020_000, attention: .active),
        Template(title: "lofi beats to not focus to", source: .youtube, creator: "a chilled cow",
                 durationMs: 7_200_000, consumedMs: 3_600_000, attention: .background),
        Template(title: "Scroll — TikTok", source: .tiktok, attention: .active, kind: .session,
                 titles: ["a duck with a job", "the physics of a bad chair", "23 second pasta", "london rain asmr"]),
        Template(title: "Hacker News — front page", source: .web, creator: "news.ycombinator.com",
                 durationMs: 900_000, consumedMs: 840_000, attention: .active),
        Template(title: "Piranesi — ch. 14", source: .kindle, creator: "Susanna Clarke",
                 durationMs: 1_800_000, consumedMs: 1_500_000, attention: .active),
        Template(title: "Search Engine — Ep. 88", source: .podcast, creator: "PJ Vogt",
                 durationMs: 3_000_000, consumedMs: 1_200_000, attention: .background),
    ]

    /// A pending, sample-tagged detection that ended at most 14 minutes ago.
    public static func makePending<R: RandomNumberGenerator>(now: Date, calendar: Calendar,
                                                             using rng: inout R) -> LogEntry {
        let p = pool[Int.random(in: 0 ..< pool.count, using: &rng)]
        let minutes: Int
        if p.kind == .session {
            minutes = 8 + Int.random(in: 0 ..< 20, using: &rng)
        } else {
            minutes = max(2, Int((Double(p.consumedMs ?? 600_000) / 60_000).rounded()))
        }
        let dayStart = Day(now, calendar: calendar).start(calendar)
        let lag = Double(Int.random(in: 0 ..< 14, using: &rng)) * 60
        let start = max(dayStart, now.addingTimeInterval(-Double(minutes) * 60 - lag)).wholeSecond
        let end = min(now, start.addingTimeInterval(Double(minutes) * 60)).wholeSecond
        let items = p.titles.map { titles in
            titles.map { SessionItem(title: $0, source: p.source,
                                     durationMs: Int.random(in: 35 ... 124, using: &rng) * 1000,
                                     consumedMs: Int.random(in: 20 ... 89, using: &rng) * 1000) }
        }
        return LogEntry(kind: p.kind, start: start, end: max(end, start.addingTimeInterval(60)), title: p.title,
                        category: p.attention == .background ? .mediaBackground : .media,
                        source: p.source, creator: p.creator, durationMs: p.durationMs, consumedMs: p.consumedMs,
                        attention: p.attention, items: items, origin: .auto,
                        confidence: 0.62 + Double.random(in: 0 ..< 0.34, using: &rng),
                        status: .pending, sample: true)
    }
}
