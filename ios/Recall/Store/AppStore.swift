import Observation
import RecallCore
import SwiftUI
import UIKit

nonisolated enum AppTab: Hashable, Sendable {
    case today, archive, insights
}

nonisolated enum SheetRoute: Identifiable, Hashable, Sendable {
    case quickAdd(switching: Bool)
    case backfill(from: Date, to: Date)
    case detail(UUID)
    case share
    case you

    var id: String {
        switch self {
        case .quickAdd(let switching): return "quick-\(switching)"
        case .backfill(let from, let to): return "backfill-\(from.timeIntervalSince1970)-\(to.timeIntervalSince1970)"
        case .detail(let id): return "detail-\(id.uuidString)"
        case .share: return "share"
        case .you: return "you"
        }
    }
}

nonisolated struct ToastMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let duration: Double
}

/// The single source of truth. Every intent goes through a RecallCore mutation
/// (unit-tested on Linux), then a debounced atomic save.
@Observable
final class AppStore {
    private(set) var data: RecallData
    var tab: AppTab = .today
    var day: Day
    var sheet: SheetRoute?
    var toast: ToastMessage?
    /// Only one row may have its swipe rail open (§5).
    var openSwipeRow: UUID?
    /// Bumped to ask Today to scroll back to the top (re-tapping its tab).
    var scrollToTopRequest = 0
    /// A link handed over by the system PasteButton, picked up by the capture sheet.
    var pastedURL: URL?

    let calendar: Calendar
    let isUITesting: Bool
    let persistence: Persistence
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(data: RecallData, persistence: Persistence, calendar: Calendar, isUITesting: Bool) {
        self.data = data
        self.persistence = persistence
        self.calendar = calendar
        self.isUITesting = isUITesting
        self.day = Day(Date(), calendar: calendar)
    }

    static func bootstrap() -> AppStore {
        let testing = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let persistence = testing ? Persistence.temporary() : Persistence.live()
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        var data: RecallData
        var note: String?
        switch persistence.load() {
        case .loaded(let loaded):
            data = loaded
        case .missing:
            data = Seed.sampleSnapshot(now: now, calendar: calendar)
        case .unreadable(let movedTo):
            data = RecallData()
            note = "Couldn't read saved data — kept a copy (\(movedTo.lastPathComponent))"
        }
        data.prunePending(now: now)
        if testing {
            data.simulateAutoCapture = false
            data.hintsShown = 99
        }
        let store = AppStore(data: data, persistence: persistence, calendar: calendar, isUITesting: testing)
        if let note { store.showToast(note, duration: 4) }
        store.scheduleSave()
        return store
    }

    // MARK: derived

    var entries: [LogEntry] { data.entries }
    var liveEntry: LogEntry? { data.liveEntry }
    var today: Day { Day(Date(), calendar: calendar) }

    func entries(on day: Day, now: Date = Date()) -> [LogEntry] {
        DayTimeline.entries(on: day, from: data.entries, now: now, calendar: calendar)
    }

    func entry(_ id: UUID) -> LogEntry? { data.entry(id: id) }

    func topFrequents(_ count: Int, at date: Date = Date()) -> [Frequent] {
        Suggestions.topFrequents(data.frequents, hour: calendar.component(.hour, from: date), count: count)
    }

    func hhmm(_ date: Date) -> String { Fmt.hhmm(date, calendar: calendar) }

    // MARK: capture

    func startBlock(_ title: String, category: EntryCategory = .life, place: String? = nil) {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Motion.animate(.gentle) {
            mutate { $0.startBlock(title: name, category: category, place: place, now: Date()) }
            if day != today { day = today }
        }
        Haptics.thud()
        showToast("Started “\(name)”")
    }

    func stopLive() {
        var stopped: LogEntry?
        Motion.animate(.gentle) {
            stopped = mutate { $0.stopLive(now: Date()) }
        }
        guard let stopped else { return }
        Haptics.thud()
        showToast("Stopped · \(Fmt.duration(minutes: DayTimeline.lengthMinutes(stopped, now: Date())))")
    }

    func again(_ entry: LogEntry) {
        Motion.animate(.gentle) {
            mutate { $0.again(id: entry.id, now: Date()) }
            if day != today { day = today }
        }
        Haptics.thud()
        showToast("Started “\(entry.title)” again")
    }

    func backfill(from: Date, to: Date, title: String, attention: Attention) {
        var added: LogEntry?
        Motion.animate(.gentle) {
            added = mutate { $0.backfill(from: from, to: to, title: title, attention: attention) }
        }
        Haptics.thud()
        if let added {
            showToast("Filled \(Fmt.duration(added.end?.timeIntervalSince(added.start) ?? 0))")
        }
    }

    func addShared(_ media: SharedMedia, attention: Attention) {
        Motion.animate(.gentle) {
            mutate { $0.addShared(media, attention: attention, now: Date()) }
            if day != today { day = today }
        }
        Haptics.thud()
        showToast("Saved to today")
    }

    // MARK: corrections

    func split(_ entry: LogEntry) {
        guard !entry.isLive else {
            showToast("Stop the block first")
            return
        }
        var second: LogEntry?
        Motion.animate(.gentle) {
            second = mutate { $0.split(id: entry.id) }
        }
        if second == nil {
            showToast("Too short to split")
        } else {
            Haptics.tap()
            showToast("Split in two — rename the halves")
        }
    }

    func delete(_ entry: LogEntry) {
        Motion.animate(.gentle) {
            mutate { $0.delete(id: entry.id) }
        }
        if openSwipeRow == entry.id { openSwipeRow = nil }
        if case .detail(let id) = sheet, id == entry.id { sheet = nil }
        Haptics.tap()
        showToast("Deleted")
    }

    func retime(_ entry: LogEntry, to start: Date) {
        Motion.animate(.gentle) {
            mutate { $0.retime(id: entry.id, to: start, now: Date(), calendar: calendar) }
        }
        Haptics.thud()
        if let moved = self.entry(entry.id) {
            showToast("Moved to \(hhmm(moved.start))")
        }
    }

    func confirm(_ entry: LogEntry) {
        Motion.animate(.gentle) {
            mutate { $0.confirmPending(id: entry.id) }
        }
        Haptics.tap()
        showToast("Kept")
    }

    func discard(_ entry: LogEntry) {
        Motion.animate(.gentle) {
            mutate { $0.delete(id: entry.id) }
        }
        Haptics.tap()
        showToast("Discarded")
    }

    func setAttention(_ entry: LogEntry, _ attention: Attention) {
        mutate { $0.setAttention(id: entry.id, attention) }
        showToast("Attention updated")
    }

    /// Edits from the detail sheet (title, times, place, thought).
    func update(_ entry: LogEntry) {
        mutate { $0.update(entry) }
    }

    func addNoteToLive(_ text: String) {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty, var live = liveEntry else { return }
        live.note = [live.note, note].compactMap { $0 }.joined(separator: " · ")
        mutate { $0.update(live) }
        Haptics.tap()
        showToast("Note added")
    }

    func attachPhotoToLive(_ data: Data) {
        guard var live = liveEntry else { return }
        let jpeg = UIImage(data: data)
            .flatMap { $0.preparingThumbnail(of: CGSize(width: 1600, height: 1600 * $0.size.height / max($0.size.width, 1))) ?? $0 }
            .flatMap { $0.jpegData(compressionQuality: 0.82) }
        guard let jpeg, let name = persistence.savePhoto(jpeg) else {
            showToast("Couldn't attach that photo")
            return
        }
        live.photos = (live.photos ?? []) + [name]
        mutate { $0.update(live) }
        Haptics.tap()
        showToast("Photo attached")
    }

    func photo(named name: String) -> UIImage? {
        UIImage(contentsOfFile: persistence.photoURL(name).path(percentEncoded: false))
    }

    // MARK: view state

    func setDensity(_ density: Density) {
        guard density != data.density else { return }
        Motion.animate(.gentle) {
            mutate { $0.density = density }
        }
        Haptics.thud()
    }

    func cycleDensity() {
        setDensity(data.density.cycled)
    }

    func setTheme(_ theme: ThemePreference) {
        guard theme != data.theme else { return }
        mutate { $0.theme = theme }
        applyTheme()
    }

    /// The ◐ button: flip whatever is showing now to the other appearance.
    func toggleTheme(currentlyDark: Bool) {
        setTheme(currentlyDark ? .light : .dark)
        Haptics.tick()
    }

    /// Applied to the windows directly — `preferredColorScheme(nil)` doesn't reliably
    /// return a running app to the system appearance.
    func applyTheme() {
        let style: UIUserInterfaceStyle
        switch data.theme {
        case .auto: style = .unspecified
        case .light: style = .light
        case .dark: style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    func setSimulation(_ on: Bool) {
        guard on != data.simulateAutoCapture else { return }
        mutate { $0.simulateAutoCapture = on }
        showToast(on ? "Auto-capture on" : "Auto-capture off")
    }

    func clearSamples() {
        Motion.animate(.gentle) {
            mutate { $0.clearSamples() }
        }
        openSwipeRow = nil
        Haptics.thud()
        showToast("Sample data cleared — it's all yours now")
    }

    func loadSamples() {
        Motion.animate(.gentle) {
            mutate { $0.loadSamples(now: Date(), calendar: calendar) }
        }
        Haptics.thud()
        showToast("Sample days loaded")
    }

    func select(_ newTab: AppTab) {
        if newTab == tab {
            if newTab == .today {
                if day != today { day = today }
                scrollToTopRequest += 1
            }
            return
        }
        tab = newTab
        Haptics.tick()
    }

    func shiftDay(by days: Int) {
        day = day.adding(days: days, calendar: calendar)
        openSwipeRow = nil
    }

    func show(day newDay: Day) {
        day = newDay
        tab = .today
        openSwipeRow = nil
    }

    func open(_ route: SheetRoute) {
        sheet = route
        Haptics.tap()
    }

    func dismissSheet() {
        sheet = nil
    }

    func showToast(_ text: String, duration: Double = 1.9) {
        toast = ToastMessage(id: UUID(), text: text, duration: duration)
    }

    // MARK: simulated auto-ingest (§6.6)

    func runAutoCaptureLoop() async {
        var rng = SystemRandomNumberGenerator()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 22 ... 42, using: &rng)))
            if Task.isCancelled { return }
            guard data.simulateAutoCapture, !isUITesting, day == today else { continue }
            fireAutoCapture()
        }
    }

    func fireAutoCapture() {
        var rng = SystemRandomNumberGenerator()
        let detected = AutoIngest.makePending(now: Date(), calendar: calendar, using: &rng)
        Motion.animate(.gentle) {
            mutate { $0.entries.append(detected) }
        }
        Haptics.tick()
        let title = detected.title.count > 30 ? String(detected.title.prefix(30)) + "…" : detected.title
        showToast("Detected · \(title)", duration: 2.4)
    }

    func showFirstLaunchHint() async {
        guard data.hintsShown < 3 else { return }
        try? await Task.sleep(for: .milliseconds(900))
        showToast("Hold ⊕ for frequents · pinch the timeline", duration: 3)
        mutate { $0.hintsShown += 1 }
    }

    // MARK: persistence

    @discardableResult
    private func mutate<T>(_ body: (inout RecallData) -> T) -> T {
        let result = body(&data)
        scheduleSave()
        return result
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = data
        let url = persistence.fileURL
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) {
                Persistence.write(snapshot, to: url)
            }.value
        }
    }

    /// Called when the app leaves the foreground.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        Persistence.write(data, to: persistence.fileURL)
    }

    func exportFile() -> URL? {
        persistence.writeExport(data.entries, day: today)
    }
}
