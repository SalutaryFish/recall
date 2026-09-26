import Foundation
import XCTest
@testable import RecallCore

final class RecallCoreTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        // corelibs Foundation can't read tzdata on NixOS (no /usr/share/zoneinfo); UTC keeps
        // every test except the DST one meaningful there.
        c.timeZone = TimeZone(identifier: "Europe/London") ?? TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }()

    /// Saturday 26 Sep 2026, 14:43 in London.
    lazy var now: Date = at(2026, 9, 26, 14, 43)
    lazy var today = Day(now, calendar: cal)

    func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func block(_ title: String, _ s: Date, _ e: Date?, cat: EntryCategory = .life) -> LogEntry {
        LogEntry(start: s, end: e, title: title, category: cat)
    }

    // MARK: formatting

    func testFormatters() {
        XCTAssertEqual(Fmt.hhmm(minutes: 430), "07:10")
        XCTAssertEqual(Fmt.hhmm(minutes: 1445), "00:05")
        XCTAssertEqual(Fmt.duration(minutes: 45), "45m")
        XCTAssertEqual(Fmt.duration(minutes: 120), "2h")
        XCTAssertEqual(Fmt.duration(minutes: 65), "1h05m")
        XCTAssertEqual(Fmt.duration(minutes: 84), "1h24m")
        XCTAssertEqual(Fmt.clock(0), "0:00:00")
        XCTAssertEqual(Fmt.clock(5046), "1:24:06")
        XCTAssertEqual(Fmt.dateLabel(today, calendar: cal), "SAT · 26 SEP 2026")
        XCTAssertEqual(Fmt.dayTitle(today, today: today, calendar: cal), "Today")
        XCTAssertEqual(Fmt.dayTitle(today.adding(days: -1, calendar: cal), today: today, calendar: cal), "Yesterday")
        XCTAssertEqual(Fmt.dayTitle(today.adding(days: -3, calendar: cal), today: today, calendar: cal), "Wednesday")
        XCTAssertEqual(Fmt.monthYear(today), "SEPTEMBER 2026")
        XCTAssertEqual(Fmt.shortDate(today), "26 Sep")
        XCTAssertEqual(Fmt.grouped(5841), "5,841")
        XCTAssertEqual(Fmt.grouped(999), "999")
        XCTAssertEqual(Fmt.grouped(1_234_567), "1,234,567")
    }

    // MARK: days

    func testDayArithmetic() {
        XCTAssertEqual(today.key, "2026-09-26")
        XCTAssertEqual(Day(key: "2026-09-26"), today)
        XCTAssertEqual(today.adding(days: 6, calendar: cal).key, "2026-10-02")
        XCTAssertEqual(today.days(to: today.adding(days: -40, calendar: cal), calendar: cal), -40)
        // Clocks go back on 25 Oct 2026 in London: a 25-hour day.
        if cal.timeZone.identifier == "Europe/London" {
            XCTAssertEqual(Day(year: 2026, month: 10, day: 25).lengthInMinutes(cal), 1500)
        }
        XCTAssertEqual(Day(year: 2026, month: 9, day: 1).mondayIndex(cal), 1) // Tuesday
        XCTAssertEqual(Day(year: 2028, month: 2, day: 29).yearEarlier(cal).key, "2027-02-28")
    }

    // MARK: timeline

    func testRowsInsertGapsOfTwentyMinutesOrMore() {
        let a = block("A", at(2026, 9, 26, 9, 0), at(2026, 9, 26, 10, 0))
        let b = block("B", at(2026, 9, 26, 10, 19), at(2026, 9, 26, 11, 0)) // 19 min gap: no row
        let c = block("C", at(2026, 9, 26, 11, 20), at(2026, 9, 26, 12, 0)) // 20 min gap: row
        let list = DayTimeline.entries(on: today, from: [c, a, b], now: now, calendar: cal)
        let rows = DayTimeline.rows(for: list, day: today, now: now, calendar: cal)
        XCTAssertEqual(rows.count, 5) // A B gap C + trailing gap to now
        if case .gap(let s, let e) = rows[2] {
            XCTAssertEqual(s, at(2026, 9, 26, 11, 0))
            XCTAssertEqual(e, at(2026, 9, 26, 11, 20))
        } else { XCTFail("expected a gap") }
        if case .gap(_, let e) = rows[4] { XCTAssertEqual(e, now) } else { XCTFail("expected trailing gap") }
    }

    func testNoTrailingGapWhileLiveOrOnPastDays() {
        let a = block("A", at(2026, 9, 26, 9, 0), at(2026, 9, 26, 10, 0))
        let live = block("Live", at(2026, 9, 26, 13, 0), nil)
        let rows = DayTimeline.rows(for: [a, live], day: today, now: now, calendar: cal)
        XCTAssertEqual(rows.map(\.id).count, 3) // A, gap, live
        let yesterday = today.adding(days: -1, calendar: cal)
        let y = block("Y", at(2026, 9, 25, 9, 0), at(2026, 9, 25, 10, 0))
        XCTAssertEqual(DayTimeline.rows(for: [y], day: yesterday, now: now, calendar: cal).count, 1)
    }

    func testOverlappingEntriesDoNotCreateFalseGaps() {
        let long = block("Long", at(2026, 9, 26, 9, 0), at(2026, 9, 26, 12, 0))
        let inner = block("Inner", at(2026, 9, 26, 9, 30), at(2026, 9, 26, 9, 40))
        let next = block("Next", at(2026, 9, 26, 12, 5), at(2026, 9, 26, 13, 0))
        let rows = DayTimeline.rows(for: [long, inner, next], day: today, now: at(2026, 9, 26, 13, 10), calendar: cal)
        XCTAssertFalse(rows.dropLast().contains { if case .gap = $0 { return true } else { return false } })
    }

    func testMidnightCrossingEntryAppearsOnBothDaysClipped() {
        let sleep = block("Sleep", at(2026, 9, 25, 23, 0), at(2026, 9, 26, 7, 0), cat: .sleep)
        let yesterday = today.adding(days: -1, calendar: cal)
        XCTAssertEqual(DayTimeline.entries(on: today, from: [sleep], now: now, calendar: cal).count, 1)
        XCTAssertEqual(DayTimeline.entries(on: yesterday, from: [sleep], now: now, calendar: cal).count, 1)
        XCTAssertEqual(DayTimeline.clippedMinutes(sleep, day: today, now: now, calendar: cal), 420)
        XCTAssertEqual(DayTimeline.clippedMinutes(sleep, day: yesterday, now: now, calendar: cal), 60)
        let endsAtMidnight = block("E", at(2026, 9, 25, 22, 0), at(2026, 9, 26, 0, 0))
        XCTAssertTrue(DayTimeline.entries(on: today, from: [endsAtMidnight], now: now, calendar: cal).isEmpty)
    }

    func testStatsCountSessionItemsAndIgnoreBackgroundAttention() {
        var session = block("Scroll", at(2026, 9, 26, 11, 0), at(2026, 9, 26, 11, 40), cat: .media)
        session.kind = .session
        session.items = (0 ..< 7).map { SessionItem(title: "\($0)") }
        var bg = block("Album", at(2026, 9, 26, 12, 0), at(2026, 9, 26, 13, 0), cat: .mediaBackground)
        bg.kind = .media
        bg.attention = .background
        let s = DayTimeline.stats(for: [session, bg], day: today, now: now, calendar: cal)
        XCTAssertEqual(s.trackedMinutes, 100)
        XCTAssertEqual(s.mediaAttentionMinutes, 40)
        XCTAssertEqual(s.mediaItems, 8)
    }

    func testRowHeights() {
        XCTAssertNil(DayTimeline.rowHeight(minutes: 30, density: .transcript))
        XCTAssertEqual(DayTimeline.rowHeight(minutes: 2, density: .proportional), 53) // 44 + 34·log2(1.2)
        XCTAssertEqual(DayTimeline.rowHeight(minutes: 0, density: .proportional), 44)
        XCTAssertEqual(DayTimeline.rowHeight(minutes: 10_000, density: .proportional), 300)
        XCTAssertEqual(DayTimeline.rowHeight(minutes: 2, density: .ribbon), 44)
        XCTAssertEqual(DayTimeline.rowHeight(minutes: 60, density: .ribbon), 90)
        XCTAssertEqual(DayTimeline.rowHeight(minutes: 1440, density: .ribbon), 900)
    }

    func testRibbonSegmentsSkipUntrackedTime() {
        let a = block("A", at(2026, 9, 26, 6, 0), at(2026, 9, 26, 12, 0), cat: .focus)
        let segs = DayTimeline.ribbon(for: [a], day: today, now: now, calendar: cal)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs[0].from, 0.25, accuracy: 0.0001)
        XCTAssertEqual(segs[0].to, 0.5, accuracy: 0.0001)
        XCTAssertEqual(segs[0].category, .focus)
    }

    func testRetimeDeltaSnapsToFiveMinutes() {
        XCTAssertEqual(DayTimeline.retimeDelta(dragPoints: 5, density: .transcript), 5)   // 3.75 → 5
        XCTAssertEqual(DayTimeline.retimeDelta(dragPoints: 3, density: .transcript), 0)   // 2.25 → 0
        XCTAssertEqual(DayTimeline.retimeDelta(dragPoints: -40, density: .transcript), -30)
        XCTAssertEqual(DayTimeline.retimeDelta(dragPoints: 45, density: .ribbon), 30)
    }

    // MARK: mutations

    func testStartBlockEndsLiveAndBumpsFrequent() {
        var s = RecallData()
        s.startBlock(title: "Deep work", category: .focus, now: at(2026, 9, 26, 9, 0))
        s.startBlock(title: "coffee", now: at(2026, 9, 26, 9, 30))
        XCTAssertEqual(s.entries.count, 2)
        XCTAssertEqual(s.entries[0].end, at(2026, 9, 26, 9, 30))
        XCTAssertEqual(s.liveEntry?.title, "coffee")
        XCTAssertEqual(s.frequents.first { $0.name == "Coffee" }?.uses, 1)
        XCTAssertEqual(s.frequents.first { $0.name == "Deep work" }?.uses, 1)
        let stopped = s.stopLive(now: at(2026, 9, 26, 9, 30))
        XCTAssertEqual(stopped?.end, at(2026, 9, 26, 9, 31)) // never shorter than a minute
        XCTAssertNil(s.liveEntry)
    }

    func testSplitSharesItemsAndConsumedTime() {
        var e = block("Browsing", at(2026, 9, 26, 9, 0), at(2026, 9, 26, 13, 0), cat: .media)
        e.kind = .session
        e.items = (0 ..< 5).map { SessionItem(title: "\($0)") }
        e.consumedMs = 1000
        var s = RecallData(entries: [e])
        let second = s.split(id: e.id)
        XCTAssertEqual(s.entries.count, 2)
        XCTAssertEqual(s.entries[0].end, at(2026, 9, 26, 11, 0))
        XCTAssertEqual(second?.start, at(2026, 9, 26, 11, 0))
        XCTAssertEqual(second?.title, "Browsing (2)")
        XCTAssertEqual(s.entries[0].items?.count, 2)
        XCTAssertEqual(second?.items?.count, 3)
        XCTAssertEqual((s.entries[0].consumedMs ?? 0) + (second?.consumedMs ?? 0), 1000)
        var live = RecallData(entries: [block("Live", at(2026, 9, 26, 9, 0), nil)])
        XCTAssertNil(live.split(id: live.entries[0].id))
    }

    func testRetimeKeepsLengthAndStaysInDayAndPast() {
        let e = block("Lunch", at(2026, 9, 26, 12, 0), at(2026, 9, 26, 13, 0))
        var s = RecallData(entries: [e])
        s.retime(id: e.id, to: at(2026, 9, 26, 12, 25), now: now, calendar: cal)
        XCTAssertEqual(s.entries[0].start, at(2026, 9, 26, 12, 25))
        XCTAssertEqual(s.entries[0].end, at(2026, 9, 26, 13, 25))
        s.retime(id: e.id, to: at(2026, 9, 25, 23, 0), now: now, calendar: cal)
        XCTAssertEqual(s.entries[0].start, today.start(cal))
        s.retime(id: e.id, to: at(2026, 9, 26, 20, 0), now: now, calendar: cal)
        XCTAssertEqual(s.entries[0].start, now)
    }

    func testBackfillUsesFrequentCategory() {
        var s = RecallData()
        let e = s.backfill(from: at(2026, 9, 26, 13, 0), to: at(2026, 9, 26, 14, 0), title: " deep work ", attention: .active)
        XCTAssertEqual(e.category, .focus)
        XCTAssertEqual(e.title, "deep work")
        let u = s.backfill(from: at(2026, 9, 26, 15, 0), to: at(2026, 9, 26, 15, 30), title: "", attention: .active)
        XCTAssertEqual(u.title, "Untracked")
    }

    func testPendingExpiresAfterAWeek() {
        var old = block("Old", at(2026, 9, 18, 9, 0), at(2026, 9, 18, 9, 30), cat: .media)
        old.status = .pending
        var fresh = old
        fresh.id = UUID()
        fresh.start = at(2026, 9, 25, 9, 0)
        var kept = old
        kept.id = UUID()
        kept.status = .confirmed
        var s = RecallData(entries: [old, fresh, kept])
        s.prunePending(now: now)
        XCTAssertEqual(s.entries.map(\.id), [fresh.id, kept.id])
    }

    func testSetAttentionMovesMediaCategory() {
        var e = block("Album", at(2026, 9, 26, 12, 0), at(2026, 9, 26, 13, 0), cat: .media)
        e.kind = .media
        var s = RecallData(entries: [e])
        s.setAttention(id: e.id, .background)
        XCTAssertEqual(s.entries[0].category, .mediaBackground)
        XCTAssertEqual(s.entries[0].attention, .background)
    }

    // MARK: seed + samples

    func testSeedInvariants() {
        let s = Seed.sampleSnapshot(now: now, calendar: cal)
        XCTAssertEqual(s.entries.filter(\.isLive).count, 1)
        XCTAssertTrue(s.entries.allSatisfy(\.isSample))
        XCTAssertTrue(s.entries.allSatisfy { $0.start <= now && ($0.end ?? now) <= now })
        let todays = DayTimeline.entries(on: today, from: s.entries, now: now, calendar: cal)
        for (a, b) in zip(todays, todays.dropFirst()) {
            XCTAssertLessThanOrEqual(a.end ?? now, b.start, "\(a.title) overlaps \(b.title)")
        }
        // 14:43 → everything up to "Hyperpop for Cooking" (ends 14:05), then live from 14:05.
        XCTAssertEqual(todays.last?.title, "Deep work — Design")
        XCTAssertEqual(todays.last?.start, at(2026, 9, 26, 14, 5))
        XCTAssertEqual(DayTimeline.entries(on: today.adding(days: -1, calendar: cal), from: s.entries,
                                           now: now, calendar: cal).count, 10)
        XCTAssertEqual(DayTimeline.entries(on: today.adding(days: -2, calendar: cal), from: s.entries,
                                           now: now, calendar: cal).count, 8)
        XCTAssertEqual(s.history.count, 67)
        XCTAssertEqual(s.history[today.adding(days: -3, calendar: cal).key], 0.41) // prototype LCG, first draw
        XCTAssertEqual(s.frequents.first { $0.name == "Coffee" }?.uses, 142)
        XCTAssertNotNil(ArchiveMath.onThisDay(today: today, entries: s.entries, now: now, calendar: cal))
    }

    func testSeedAtTwentyPastMidnightHasOnlyTheLiveEntryToday() {
        let early = at(2026, 9, 26, 0, 20)
        let s = Seed.sampleSnapshot(now: early, calendar: cal)
        let todays = DayTimeline.entries(on: today, from: s.entries, now: early, calendar: cal)
        XCTAssertEqual(todays.count, 1)
        XCTAssertEqual(todays[0].start, today.start(cal))
    }

    func testClearSamplesKeepsWhatTheUserLogged() {
        var s = Seed.sampleSnapshot(now: now, calendar: cal)
        s.stopLive(now: now)
        let mine = s.startBlock(title: "Coffee", now: now.addingTimeInterval(60))
        s.clearSamples()
        XCTAssertEqual(s.entries.map(\.id), [mine.id])
        XCTAssertTrue(s.history.isEmpty)
        XCTAssertFalse(s.hasSamples)
        XCTAssertFalse(s.simulateAutoCapture)
        XCTAssertEqual(s.frequents.first { $0.name == "Coffee" }?.uses, 1)
        XCTAssertEqual(s.counters.sampleDays, 0)
        s.loadSamples(now: now.addingTimeInterval(120), calendar: cal)
        XCTAssertTrue(s.hasSamples)
        XCTAssertEqual(s.entries.filter(\.isLive).count, 1, "the user's live block wins over the sample one")
        XCTAssertEqual(s.frequents.first { $0.name == "Coffee" }?.uses, 143)
    }

    func testOnThisDaySentence() {
        let s = Seed.sampleSnapshot(now: now, calendar: cal)
        let otd = ArchiveMath.onThisDay(today: today, entries: s.entries, now: now, calendar: cal)
        XCTAssertEqual(otd?.day.key, "2025-09-26")
        XCTAssertEqual(otd?.text, "You were in Lisbon. Sunset at Miradouro da Graça. "
            + "Logged 11 media — nine of them short video — and walked 14,203 steps.")
    }

    // MARK: suggestions, insights, archive

    func testTopFrequentsPreferTheCurrentHour() {
        let s = Seed.sampleSnapshot(now: now, calendar: cal)
        XCTAssertEqual(Suggestions.topFrequents(s.frequents, hour: 22, count: 3).map(\.name), ["YouTube", "Sleep", "Read"])
        XCTAssertEqual(Suggestions.topFrequents(s.frequents, hour: 3, count: 2).map(\.name), ["Coffee", "Deep work"])
    }

    func testAutocompleteAndSearch() {
        let s = Seed.sampleSnapshot(now: now, calendar: cal)
        let hits = Suggestions.autocomplete("deep", entries: s.entries, hour: 10, calendar: cal)
        XCTAssertEqual(hits.first?.kind, .block)
        XCTAssertTrue(hits.first?.text.hasPrefix("Deep work") ?? false)
        let places = Suggestions.autocomplete("shore", entries: s.entries, hour: 10, calendar: cal)
        XCTAssertEqual(places.map(\.text), ["PureGym Shoreditch"])
        XCTAssertTrue(Suggestions.search("d", in: s.entries).isEmpty)
        XCTAssertFalse(Suggestions.search("lisbon", in: s.entries).isEmpty)
        XCTAssertLessThanOrEqual(Suggestions.search("e", in: s.entries).count, 8)
    }

    func testWeekInsights() {
        let s = Seed.sampleSnapshot(now: now, calendar: cal)
        let w = InsightsBuilder.week(ending: today, entries: s.entries, now: now, calendar: cal)
        XCTAssertEqual(w.dayCount, 3)
        XCTAssertGreaterThan(w.activeMedia, 0)
        XCTAssertGreaterThan(w.backgroundMedia, 0)
        XCTAssertEqual(w.longestFocus?.title, "Deep work — Recall spec")
        XCTAssertEqual(w.longestFocusMinutes, 180)
        XCTAssertEqual(w.sources.first?.source, .netflix)
        XCTAssertGreaterThan(w.finished, 0)
    }

    func testMonthGridIsMondayFirst() {
        let grid = ArchiveMath.monthGrid(containing: today, calendar: cal)
        XCTAssertEqual(grid.leadingBlanks, 1) // 1 Sep 2026 is a Tuesday
        XCTAssertEqual(grid.days.count, 30)
        XCTAssertEqual(ArchiveMath.level(0), 0)
        XCTAssertEqual(ArchiveMath.level(0.5), 2)
        XCTAssertEqual(ArchiveMath.level(1), 4)
    }

    func testHeatmapFillUsesHistoryThenDetail() {
        let s = Seed.sampleSnapshot(now: now, calendar: cal)
        let old = today.adding(days: -10, calendar: cal)
        XCTAssertEqual(ArchiveMath.fill(for: old, snapshot: s, now: now, calendar: cal), s.history[old.key])
        let yesterday = today.adding(days: -1, calendar: cal)
        XCTAssertGreaterThan(ArchiveMath.fill(for: yesterday, snapshot: s, now: now, calendar: cal), 0.5)
        XCTAssertEqual(ArchiveMath.fill(for: today.adding(days: 3, calendar: cal), snapshot: s, now: now, calendar: cal), 0)
    }

    // MARK: ingest + codec

    func testSourceDetection() {
        XCTAssertEqual(SourceDetector.source(for: URL(string: "https://youtu.be/abc")!), .youtube)
        XCTAssertEqual(SourceDetector.source(for: URL(string: "https://m.youtube.com/watch?v=1")!), .youtube)
        XCTAssertEqual(SourceDetector.source(for: URL(string: "https://www.tiktok.com/@x/video/1")!), .tiktok)
        XCTAssertEqual(SourceDetector.source(for: URL(string: "https://open.spotify.com/album/1")!), .spotify)
        XCTAssertEqual(SourceDetector.source(for: URL(string: "https://podcasts.apple.com/gb/podcast/x")!), .podcast)
        XCTAssertEqual(SourceDetector.source(for: URL(string: "https://notyoutube.com")!), .web)
        XCTAssertEqual(SourceDetector.host(of: URL(string: "https://www.example.org/a")!), "example.org")
    }

    func testAutoIngestMakesSamplePendingEntriesInThePast() {
        var rng = SeededRandom(seed: 7)
        for _ in 0 ..< 50 {
            let e = AutoIngest.makePending(now: now, calendar: cal, using: &rng)
            XCTAssertTrue(e.isPending)
            XCTAssertTrue(e.isSample)
            XCTAssertLessThanOrEqual(e.end ?? .distantFuture, now.addingTimeInterval(60))
            XCTAssertGreaterThanOrEqual(e.start, today.start(cal))
            XCTAssertNotNil(e.confidence)
        }
    }

    func testSharedMediaIsBackdatedByItsLength() {
        var s = RecallData()
        let e = s.addShared(SharePool.samples[1], attention: .active, now: now)
        XCTAssertEqual(e.end, now)
        XCTAssertEqual(e.start, now.addingTimeInterval(-21 * 60))
        XCTAssertEqual(e.source, .youtube)
        XCTAssertEqual(s.counters.mediaSaved, 1)
        XCTAssertNil(e.url, "sample links are not real URLs")
    }

    func testISO8601() {
        let d = Date(timeIntervalSince1970: 1_790_428_980) // 2026-09-26T13:23:00Z
        XCTAssertEqual(ISO8601.string(from: d), "2026-09-26T13:23:00Z")
        XCTAssertEqual(ISO8601.date(from: "2026-09-26T13:23:00Z"), d)
        XCTAssertEqual(ISO8601.date(from: "2026-09-26T14:23:00+01:00"), d)
        XCTAssertEqual(ISO8601.date(from: "2026-09-26T08:23:00-0500"), d)
        XCTAssertEqual(ISO8601.date(from: "2026-09-26T13:23:00.250Z")?.timeIntervalSince1970, 1_790_428_980.25)
        XCTAssertEqual(ISO8601.string(from: Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00Z")
        XCTAssertEqual(ISO8601.string(from: Date(timeIntervalSince1970: -1)), "1969-12-31T23:59:59Z")
        XCTAssertEqual(ISO8601.string(from: Date(timeIntervalSince1970: 951_782_400)), "2000-02-29T00:00:00Z")
        XCTAssertNil(ISO8601.date(from: "yesterday"))
        for t in stride(from: -2_000_000_000.0, through: 4_000_000_000, by: 86_399 * 37) {
            let date = Date(timeIntervalSince1970: t)
            XCTAssertEqual(ISO8601.date(from: ISO8601.string(from: date)), date)
        }
    }

    func testSnapshotRoundTripAndLenientDecoding() throws {
        let s = Seed.sampleSnapshot(now: now, calendar: cal)
        let back = try RecallCodec.decode(try RecallCodec.encode(s))
        XCTAssertEqual(back.entries, s.entries)
        XCTAssertEqual(back.frequents, s.frequents)
        XCTAssertEqual(back.history, s.history)
        let json = """
        {"entries":[{"id":"8C7E4E0A-0000-4000-8000-000000000001","start":"2026-09-26T09:00:00Z",
          "title":"From the future","kind":"hologram","source":"myspace","category":"focus"}]}
        """
        let decoded = try RecallCodec.decode(Data(json.utf8))
        XCTAssertEqual(decoded.entries.first?.kind, .block)
        XCTAssertNil(decoded.entries.first?.source)
        XCTAssertEqual(decoded.entries.first?.category, .focus)
        XCTAssertEqual(decoded.frequents.count, 8)
        let export = String(decoding: try RecallCodec.exportJSON(s.entries), as: UTF8.self)
        XCTAssertTrue(export.contains("\"entries\""))
        XCTAssertTrue(export.contains("T"))
    }
}
