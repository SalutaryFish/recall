import Foundation

/// Every change the app can make to the archive. Pure value mutations, so they
/// are unit-tested on Linux; the app store only adds persistence and UI feedback.
public extension RecallData {
    var liveEntry: LogEntry? { entries.first { $0.isLive && !$0.isPending } }

    func entry(id: UUID) -> LogEntry? { entries.first { $0.id == id } }

    mutating func update(_ entry: LogEntry) {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[i] = entry
    }

    /// Ends whatever is live and starts `title` now.
    @discardableResult
    mutating func startBlock(title: String, category: EntryCategory = .life, place: String? = nil,
                             now: Date) -> LogEntry {
        let now = now.wholeSecond
        endLive(at: now)
        let e = LogEntry(kind: .block, start: now, end: nil, title: title, category: category,
                         place: place, origin: .manual, status: .confirmed)
        entries.append(e)
        bumpFrequent(title)
        return e
    }

    /// Stops the live entry (never shorter than a minute). Returns the stopped entry.
    @discardableResult
    mutating func stopLive(now: Date) -> LogEntry? {
        guard let live = liveEntry, let i = entries.firstIndex(where: { $0.id == live.id }) else { return nil }
        entries[i].end = max(live.start.addingTimeInterval(60), now.wholeSecond)
        return entries[i]
    }

    private mutating func endLive(at now: Date) {
        for i in entries.indices where entries[i].isLive && !entries[i].isPending {
            entries[i].end = max(entries[i].start.addingTimeInterval(60), now)
        }
    }

    /// "Again" (swipe right / Do this again): start the same thing now.
    @discardableResult
    mutating func again(id: UUID, now: Date) -> LogEntry? {
        guard let e = entry(id: id) else { return nil }
        let category: EntryCategory = e.category == .mediaBackground ? .media : e.category
        return startBlock(title: e.title, category: category, place: e.place, now: now)
    }

    /// Split at the midpoint — the repair tool for one long "browsing" block that was
    /// really several things. Session items and consumed time are shared out.
    @discardableResult
    mutating func split(id: UUID) -> LogEntry? {
        guard let i = entries.firstIndex(where: { $0.id == id }), let end = entries[i].end else { return nil }
        let first = entries[i]
        let length = end.timeIntervalSince(first.start)
        guard length >= 120 else { return nil }
        let mid = first.start.addingTimeInterval((length / 2 / 60).rounded() * 60)
        var second = first
        second.id = UUID()
        second.start = mid
        second.title = first.title + " (2)"
        entries[i].end = mid
        if let items = first.items, items.count > 1 {
            let cut = items.count / 2
            entries[i].items = Array(items[..<cut])
            second.items = Array(items[cut...])
        }
        if let consumed = first.consumedMs {
            entries[i].consumedMs = consumed / 2
            second.consumedMs = consumed - consumed / 2
        }
        entries.insert(second, at: i + 1)
        return second
    }

    mutating func delete(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// Re-time (long-press drag): keep the length, move the start, stay inside the entry's day,
    /// never start in the future.
    mutating func retime(id: UUID, to newStart: Date, now: Date, calendar: Calendar) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        let e = entries[i]
        let day = Day(e.start, calendar: calendar)
        let latest = min(day.end(calendar).addingTimeInterval(-5 * 60), now)
        let start = max(day.start(calendar), min(newStart, latest))
        if let end = e.end {
            entries[i].end = start.addingTimeInterval(end.timeIntervalSince(e.start))
        }
        entries[i].start = start
    }

    /// Fill a gap (§2.2). EntryCategory comes from a matching frequent.
    @discardableResult
    mutating func backfill(from: Date, to: Date, title: String, attention: Attention) -> LogEntry {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = t.isEmpty ? "Untracked" : t
        let freq = frequents.first { $0.name.lowercased() == name.lowercased() }
        var category = freq?.category ?? .life
        if category.isMedia { category = attention == .background ? .mediaBackground : .media }
        let e = LogEntry(kind: .block, start: from.wholeSecond, end: max(to, from.addingTimeInterval(60)).wholeSecond,
                         title: name, category: category, attention: attention,
                         origin: .manual, status: .confirmed)
        entries.append(e)
        bumpFrequent(name)
        return e
    }

    mutating func confirmPending(id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].status = .confirmed
    }

    mutating func setAttention(id: UUID, _ attention: Attention) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].attention = attention
        if entries[i].category.isMedia || entries[i].kind == .media || entries[i].kind == .session {
            entries[i].category = attention == .background ? .mediaBackground : .media
        }
    }

    mutating func bumpFrequent(_ title: String) {
        let key = title.lowercased()
        if let i = frequents.firstIndex(where: { $0.name.lowercased() == key }) {
            frequents[i].uses += 1
        }
    }

    /// §9.4: an unreviewed auto-capture is not worth the trust it costs — expire after a week.
    mutating func prunePending(now: Date, maxAge: TimeInterval = 7 * 86_400) {
        entries.removeAll { $0.isPending && now.timeIntervalSince($0.start) > maxAge }
    }

    /// A link saved through "Save to Recall". Ends now; backdated by the work's length when known.
    @discardableResult
    mutating func addShared(_ media: SharedMedia, attention: Attention, now: Date) -> LogEntry {
        let now = now.wholeSecond
        let minutes = media.durationMs.map { max(2, (Double($0) / 60_000).rounded()) } ?? 1
        let e = LogEntry(kind: .media, start: now.addingTimeInterval(-minutes * 60), end: now,
                         title: media.title, category: attention == .background ? .mediaBackground : .media,
                         source: media.source, creator: media.creator,
                         durationMs: media.durationMs, consumedMs: media.durationMs,
                         attention: attention, origin: .share, status: .confirmed,
                         url: media.isSample ? nil : URL(string: media.url),
                         sample: media.isSample ? true : nil)
        entries.append(e)
        counters.mediaSaved += 1
        return e
    }

    /// Removes the seeded demo: sample entries, simulated captures, sample heatmap history,
    /// lived-in counters and the sample share of frequent counts. Anything logged by hand stays.
    mutating func clearSamples() {
        entries.removeAll { $0.isSample }
        history = [:]
        counters.sampleMedia = 0
        counters.sampleDays = 0
        counters.sampleHours = 0
        for i in frequents.indices {
            frequents[i].uses = max(0, frequents[i].uses - (frequents[i].sampleUses ?? 0))
            frequents[i].sampleUses = nil
        }
        simulateAutoCapture = false
        hasSamples = false
    }

    /// Brings the sample days back, merged with whatever is already there.
    mutating func loadSamples(now: Date, calendar: Calendar) {
        if hasSamples { clearSamples() }
        let seed = Seed.sampleSnapshot(now: now, calendar: calendar)
        let hasLive = liveEntry != nil
        entries.append(contentsOf: seed.entries.filter { !(hasLive && $0.isLive) })
        for (k, v) in seed.history { history[k] = v }
        counters.sampleMedia = seed.counters.sampleMedia
        counters.sampleDays = seed.counters.sampleDays
        counters.sampleHours = seed.counters.sampleHours
        for f in seed.frequents {
            if let i = frequents.firstIndex(where: { $0.name == f.name }) {
                frequents[i].uses += f.sampleUses ?? 0
                frequents[i].sampleUses = f.sampleUses
            } else {
                frequents.append(f)
            }
        }
        simulateAutoCapture = true
        hasSamples = true
    }
}

extension Date {
    /// ISO 8601 on disk drops fractional seconds; keep in-memory values identical.
    var wholeSecond: Date { Date(timeIntervalSince1970: timeIntervalSince1970.rounded(.down)) }
}
