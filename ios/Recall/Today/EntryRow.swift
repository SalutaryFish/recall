import RecallCore
import SwiftUI

/// One entry in the transcript: a 50 pt mono gutter, a 1.5 pt spine with a state dot,
/// and a card that swipes (G3/G4), lifts to re-time (G5) and taps open (G13 / detail).
struct EntryRow: View {
    @Environment(AppStore.self) private var store
    let entry: LogEntry
    let isLast: Bool
    let now: Date

    @State private var lifted = false
    @State private var liftY: CGFloat = 0
    @State private var liftDelta = 0
    @State private var liftEndedAt: Date = .distantPast
    @State private var expanded = false

    var body: some View {
        let density = store.data.density
        let minutes = DayTimeline.lengthMinutes(entry, now: now)
        let height = DayTimeline.rowHeight(minutes: minutes, density: density)
        HStack(alignment: .top, spacing: 0) {
            gutter(density: density, minutes: minutes)
            SwipeRig(entry: entry, liftEnabled: !entry.isPending,
                     onTap: { tap() },
                     onLiftBegan: { liftBegan() },
                     onLiftChanged: { translation in liftChanged(translation) },
                     onLiftEnded: { translation, cancelled in liftEnded(translation, cancelled) }) {
                EntryCard(entry: entry, now: now, expanded: expanded)
            }
            .scaleEffect(lifted ? 1.015 : 1)
            .shadow(color: .black.opacity(lifted ? 0.16 : 0), radius: 16, x: 0, y: 12)
            .offset(y: liftY)
            .overlay(alignment: .topLeading) {
                if lifted {
                    RetimeBadge(text: badgeText)
                        .offset(x: 2, y: liftY - 32)
                        .transition(.opacity)
                }
            }
            .padding(.leading, 17.5)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, minHeight: height.map { CGFloat($0) }, alignment: .topLeading)
            .background(alignment: .leading) {
                Rectangle()
                    .fill(isLast ? Color.clear : (entry.isLive ? Palette.clay : Palette.hair))
                    .frame(width: 1.5)
            }
            .overlay(alignment: .topLeading) {
                SpineDot(entry: entry)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .zIndex(lifted ? 10 : 0)
        .animation(SpringPreset.snappy.animation, value: lifted)
    }

    private func gutter(density: Density, minutes: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(store.hhmm(entry.start))
                .font(.mono(11.5))
                .foregroundStyle(entry.isLive ? Palette.clayInk : Palette.ink3)
            if density != .transcript && minutes >= 45 {
                Text(store.hhmm(DayTimeline.effectiveEnd(entry, now: now)))
                    .font(.mono(10))
                    .foregroundStyle(Palette.ink3)
                    .opacity(0.75)
            }
        }
        .frame(width: 50, alignment: .leading)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    private var badgeText: String {
        let start = entry.start.addingTimeInterval(Double(liftDelta) * 60)
        if liftDelta == 0 { return "\(store.hhmm(start)) — hold & drag" }
        return "\(store.hhmm(start))  \(liftDelta > 0 ? "+" : "")\(liftDelta)m"
    }

    // MARK: gestures

    private func tap() {
        guard Date().timeIntervalSince(liftEndedAt) > 0.3 else { return }
        if entry.kind == .session && !entry.isPending {
            withAnimation(SpringPreset.snappy.animation) { expanded.toggle() }
            Haptics.tick()
        } else {
            store.open(.detail(entry.id))
        }
    }

    private func liftBegan() {
        liftDelta = 0
        liftY = 0
        lifted = true
        if store.openSwipeRow != nil { store.openSwipeRow = nil }
        Haptics.lift()
    }

    private func liftChanged(_ translation: CGSize) {
        liftY = translation.height
        let delta = DayTimeline.retimeDelta(dragPoints: Double(translation.height), density: store.data.density)
        if delta != liftDelta {
            liftDelta = delta
            Haptics.tick()
        }
    }

    private func liftEnded(_ translation: CGSize, _ cancelled: Bool) {
        liftEndedAt = Date()
        let moved = (translation.width * translation.width + translation.height * translation.height).squareRoot()
        let delta = cancelled ? 0 : liftDelta
        if delta == 0 {
            withAnimation(SpringPreset.snappy.animation) {
                lifted = false
                liftY = 0
            }
            // A lift that never moved is a slow tap: open the detail instead (G5 cancel rule).
            if !cancelled && moved < 8 { store.open(.detail(entry.id)) }
            return
        }
        let newStart = entry.start.addingTimeInterval(Double(delta) * 60)
        withAnimation(SpringPreset.gentle.animation) {
            lifted = false
            liftY = 0
            store.retime(entry, to: newStart)
        }
        liftDelta = 0
    }
}

/// The spine dot encodes state: filled grey · hollow for background media ·
/// dashed clay for a pending detection · clay with a breathing ring when live.
struct SpineDot: View {
    let entry: LogEntry

    var body: some View {
        Group {
            if entry.isPending {
                Circle()
                    .fill(Palette.bone)
                    .overlay { Circle().strokeBorder(Palette.clay, style: StrokeStyle(lineWidth: 1.5, dash: [2, 1.5])) }
                    .frame(width: 8, height: 8)
            } else if entry.isLive {
                PulsingDot(size: 10, ring: 4)
            } else if entry.isBackground {
                Circle()
                    .fill(Palette.bone)
                    .overlay { Circle().strokeBorder(Palette.dot, lineWidth: 1.5) }
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Palette.dot)
                    .frame(width: 8, height: 8)
            }
        }
        // centred on the spine (x 0.75) at y 9, like the prototype's absolutely-placed dot
        .frame(width: 10, height: 10)
        .offset(x: 0.75 - 5, y: 9 - 5)
        .accessibilityHidden(true)
    }
}

private struct RetimeBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.mono(12))
            .foregroundStyle(Palette.bone)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .fixedSize()
            .allowsHitTesting(false)
    }
}

/// The swipe rig (`.swipe`): the card slides over two rails —
/// swipe right reveals AGAIN (commit past 45%), swipe left opens EDIT / SPLIT / DELETE.
/// Only this view reads the spring, so a swipe re-renders one row's rig and nothing else.
struct SwipeRig<Content: View>: View {
    @Environment(AppStore.self) private var store
    let entry: LogEntry
    let liftEnabled: Bool
    let onTap: () -> Void
    let onLiftBegan: () -> Void
    let onLiftChanged: (CGSize) -> Void
    let onLiftEnded: (CGSize, Bool) -> Void
    @ViewBuilder var content: Content

    @State private var offset: SpringValue = SpringValue(0, preset: .snappy)
    @State private var dragBase: Double = 0
    @State private var width: CGFloat = 300
    @State private var pastAgain = false
    @State private var pastOpen = false

    private let railWidth: Double = 74 * 3
    private var againThreshold: Double { max(110 * 0.45, Double(width) * 0.45) }

    var body: some View {
        let x = offset.value
        let swiping = abs(x) > 0.5
        ZStack {
            if swiping {
                rails(x: x)
            }
            content
                .offset(x: x)
                .accessibilityElement(children: entry.isPending ? .contain : .combine)
                .accessibilityIdentifier("entry.\(entry.title)")
                .accessibilityAddTraits(entry.isPending ? [] : .isButton)
                .accessibilityActions { actions }
        }
        .mask {
            // Clip to the card only while it is moving, so text and shadows are never cut at rest.
            RoundedRectangle(cornerRadius: swiping ? Metrics.cardRadius : 0, style: .continuous)
                .padding(swiping ? 0 : -24)
        }
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newValue in
            width = newValue
        }
        .onTapGesture {
            if offset.restingTarget != 0 || swiping {
                close()
            } else {
                onTap()
            }
        }
        .gesture(HorizontalSwipeGesture(
            onBegan: { began() },
            onChanged: { translation, _ in changed(Double(translation)) },
            onEnded: { translation, velocity in ended(Double(translation), velocity: Double(velocity)) }
        ))
        .gesture(LiftGesture(
            isEnabled: liftEnabled && !swiping,
            onBegan: { onLiftBegan() },
            onChanged: { translation in onLiftChanged(translation) },
            onEnded: { translation, cancelled in onLiftEnded(translation, cancelled) }
        ))
        .onChange(of: store.openSwipeRow) { _, openID in
            if openID != entry.id && offset.restingTarget != 0 { close() }
        }
    }

    @ViewBuilder private func rails(x: Double) -> some View {
        if x > 0 {
            ZStack(alignment: .leading) {
                Palette.clay
                Text("AGAIN")
                    .font(.mono(10.5))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .scaleEffect(pastAgain ? 1.12 : 1, anchor: .leading)
                    .animation(SpringPreset.snappy.animation, value: pastAgain)
                    .padding(.leading, 22)
            }
            .onTapGesture { commitAgain() }
        } else {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                rail("EDIT", Palette.railEdit) {
                    close()
                    store.open(.detail(entry.id))
                }
                rail("SPLIT", Palette.railSplit) {
                    close()
                    store.split(entry)
                }
                rail("DELETE", Palette.railDelete) {
                    close()
                    store.delete(entry)
                }
            }
        }
    }

    private func rail(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mono(10.5))
                .tracking(1)
                .foregroundStyle(.white)
                .frame(width: 74)
                .frame(maxHeight: .infinity)
                .background(color)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var actions: some View {
        if entry.isPending {
            Button("Keep") { store.confirm(entry) }
            Button("Discard") { store.discard(entry) }
        } else {
            Button("Edit") { store.open(.detail(entry.id)) }
            if !entry.isLive {
                Button("Split") { store.split(entry) }
            }
            Button("Delete") { store.delete(entry) }
            Button("Do this again") { store.again(entry) }
            Button("Move 5 minutes earlier") { store.retime(entry, to: entry.start.addingTimeInterval(-300)) }
            Button("Move 5 minutes later") { store.retime(entry, to: entry.start.addingTimeInterval(300)) }
        }
    }

    // MARK: swipe

    private func began() {
        dragBase = offset.value
        pastAgain = dragBase > againThreshold
        pastOpen = dragBase < -railWidth * 0.33
        if store.openSwipeRow != entry.id { store.openSwipeRow = entry.id }
    }

    private func changed(_ translation: Double) {
        var x = dragBase + translation
        x = x > 0 ? rubberBand(x, limit: 110) : rubberBand(x, limit: railWidth)
        offset.set(x)
        let beyondAgain = x > againThreshold
        if beyondAgain != pastAgain {
            pastAgain = beyondAgain
            Haptics.tick()
        }
        let beyondOpen = x < -railWidth * 0.33
        if beyondOpen != pastOpen {
            pastOpen = beyondOpen
            Haptics.tick()
        }
    }

    private func ended(_ translation: Double, velocity: Double) {
        let projected = Motion.project(offset.value, velocity: velocity)
        if projected < -railWidth * 0.33 {
            offset.animate(to: -railWidth, velocity: velocity)
            Haptics.tap()
        } else if projected > againThreshold {
            offset.animate(to: 0, velocity: velocity)
            commitAgain()
        } else {
            offset.animate(to: 0, velocity: velocity)
            if store.openSwipeRow == entry.id { store.openSwipeRow = nil }
        }
        pastAgain = false
        pastOpen = false
    }

    private func commitAgain() {
        offset.animate(to: 0)
        if store.openSwipeRow == entry.id { store.openSwipeRow = nil }
        store.again(entry)
    }

    private func close() {
        offset.animate(to: 0)
        if store.openSwipeRow == entry.id { store.openSwipeRow = nil }
    }
}
