import RecallCore
import SwiftUI

/// Today (§6.1): header + ribbon over the transcript.
/// G2 pinch → density · G9 header swipe → day · G10 pull down → yesterday's tail ·
/// G11 ribbon scrub → scroll.
struct TodayScreen: View {
    @Environment(AppStore.self) private var store
    @State private var pager: SpringValue = SpringValue(0, preset: .gentle)
    @State private var chrome: ScrollChrome = ScrollChrome()
    @State private var pagingAxis: Axis?
    @State private var pagerStart: Double = 0
    @State private var densityPreview: Density?
    @State private var peekVisible = false
    @State private var peekTask: Task<Void, Never>?
    @State private var scrubTarget: UUID?
    @State private var width: CGFloat = 402

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                DayHeader(pager: pager, chrome: chrome, densityPreview: densityPreview,
                          onScrub: { fraction in scrub(fraction, proxy: proxy) })
                    .gesture(headerDrag)
                timeline
            }
            .onChange(of: store.day) { _, _ in
                peekVisible = false
                proxy.scrollTo("top", anchor: .top)
            }
            .onChange(of: store.scrollToTopRequest) { _, _ in
                withAnimation(SpringPreset.standard.animation) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newValue in
            width = newValue
        }
    }

    private var timeline: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .id("top")
                if peekVisible {
                    YesterdayPeek(day: store.day.adding(days: -1, calendar: store.calendar))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                PagerOffset(pager: pager) {
                    TimelineContent()
                }
                .padding(.top, 6)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // room for the tab bar, ⊕ and the live bar floating over the end of the day
            Color.clear.frame(height: 146)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrolled(to: offset)
        }
        .onScrollPhaseChange { _, phase in
            phaseChanged(phase)
        }
        .simultaneousGesture(pinch)
    }

    // MARK: G10 pull + title collapse

    private func scrolled(to offset: CGFloat) {
        let collapse = min(1, max(0, offset / 64))
        if abs(collapse - chrome.collapse) > 0.001 { chrome.collapse = collapse }
        chrome.pull = max(0, -offset)
        guard chrome.interacting else { return }
        if chrome.pull > 80, !chrome.armed {
            chrome.armed = true
            Haptics.tick()
        } else if chrome.pull <= 80, chrome.armed {
            chrome.armed = false
        }
    }

    private func phaseChanged(_ phase: ScrollPhase) {
        chrome.interacting = phase == .interacting
        if phase == .interacting, store.openSwipeRow != nil {
            store.openSwipeRow = nil
        }
        if phase != .interacting, chrome.armed {
            chrome.armed = false
            revealPeek()
        }
    }

    private func revealPeek() {
        Motion.animate(.standard) { peekVisible = true }
        peekTask?.cancel()
        peekTask = Task {
            try? await Task.sleep(for: .seconds(3.4))
            guard !Task.isCancelled else { return }
            Motion.animate(.standard) { peekVisible = false }
        }
    }

    // MARK: G2 pinch

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let scale = value.magnification
                let current = store.data.density
                let target: Density? = scale > 1.25 ? current.next : (scale < 0.8 ? current.previous : nil)
                if target != densityPreview {
                    densityPreview = target
                    if target != nil { Haptics.tick() }
                }
            }
            .onEnded { _ in
                if let target = densityPreview { store.setDensity(target) }
                densityPreview = nil
            }
    }

    // MARK: G9 day paging

    private var canGoForward: Bool { store.day < store.today }

    private var headerDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if pagingAxis == nil {
                    pagingAxis = abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
                    pagerStart = pager.value
                }
                guard pagingAxis == .horizontal else { return }
                var x: Double = pagerStart + Double(value.translation.width)
                if x < 0 && !canGoForward {
                    x *= 0.25
                } else {
                    x = rubberBand(x, limit: 150, factor: 0.4)
                }
                pager.set(x)
            }
            .onEnded { value in
                defer { pagingAxis = nil }
                guard pagingAxis == .horizontal else { return }
                let velocity = Double(value.velocity.width)
                let projected = Motion.project(pager.value, velocity: velocity)
                if projected > Double(width) * 0.3 {
                    page(by: -1)
                } else if projected < -Double(width) * 0.3 && canGoForward {
                    page(by: 1)
                } else {
                    pager.animate(to: 0, velocity: velocity)
                }
            }
    }

    private func page(by days: Int) {
        Haptics.thud()
        store.shiftDay(by: days)
        // The new day enters from the side the finger came from.
        pager.snap(to: days < 0 ? -Double(width) * 0.5 : Double(width) * 0.5)
        pager.animate(to: 0)
    }

    // MARK: G11 ribbon scrub

    private func scrub(_ fraction: Double?, proxy: ScrollViewProxy) {
        guard let fraction else {
            scrubTarget = nil
            return
        }
        let date = DayTimeline.date(atFraction: fraction, in: store.day, calendar: store.calendar)
        guard let target = DayTimeline.entry(atOrBefore: date, in: store.entries(on: store.day)),
              target.id != scrubTarget else { return }
        scrubTarget = target.id
        Haptics.tick()
        proxy.scrollTo(target.id.uuidString, anchor: .top)
    }
}
