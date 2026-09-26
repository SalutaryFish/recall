import RecallCore
import SwiftUI

/// The spine of the app (§2.7): docked above the tab bar whenever something is live.
/// Drag it up to raise the live screen (G7); tap to open; ■ stops.
/// Only this thin wrapper reads the spring, so dragging re-renders nothing else.
struct LiveBar: View {
    @Environment(AppStore.self) private var store
    let live: SpringValue
    let screenHeight: CGFloat
    @State private var dragStart: Double?

    var body: some View {
        let p = live.value
        LiveBarContent()
            .opacity(min(1, max(0, p)))
            .offset(y: (1 - min(1, p)) * -14)
            .scaleEffect(1 - (1 - min(1, p)) * 0.04)
            .allowsHitTesting(p > 0.5)
            .onTapGesture { open(velocity: 0) }
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if dragStart == nil { dragStart = live.value }
                        let start = dragStart ?? 1
                        live.set(min(1.06, max(0, start + Double(value.translation.height / screenHeight))))
                    }
                    .onEnded { value in
                        dragStart = nil
                        let velocity = Double(value.velocity.height / screenHeight)
                        let projected = Motion.project(live.value, velocity: velocity)
                        if projected < 0.6 {
                            open(velocity: velocity)
                        } else {
                            live.animate(to: 1, velocity: velocity)
                        }
                    }
            )
            .accessibilityAction(named: "Expand") { open(velocity: 0) }
            .accessibilityAction(named: "Stop") { store.stopLive() }
    }

    private func open(velocity: Double) {
        live.animate(to: 0, velocity: velocity)
        Haptics.tap()
    }
}

private struct LiveBarContent: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if let entry = store.liveEntry {
            HStack(spacing: 11) {
                Circle()
                    .fill(Palette.clay)
                    .frame(width: 8, height: 8)
                    .background { Circle().fill(Palette.clayWash).padding(-3) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                        .sans(13.5, .medium)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("started \(store.hhmm(entry.start))")
                        .font(.mono(10))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 0)
                TimelineView(.periodic(from: entry.start, by: 1)) { context in
                    Text(Fmt.clock(context.date.timeIntervalSince(entry.start)))
                        .font(.mono(14))
                        .monospacedDigit()
                        .foregroundStyle(Palette.clayInk)
                }
                Button {
                    store.stopLive()
                } label: {
                    Circle()
                        .fill(Palette.wash)
                        .frame(width: 38, height: 38)
                        .overlay {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(Palette.ink)
                                .frame(width: 11, height: 11)
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.92))
                .accessibilityLabel("Stop")
                .accessibilityIdentifier("livebar.stop")
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.card)
                    .shadow(color: .black.opacity(0.09), radius: 9, x: 0, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.hair, lineWidth: 1)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Palette.hair2)
                    .frame(width: 30, height: 3)
                    .padding(.top, 5)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tracking \(entry.title)")
            .accessibilityHint("Drag up or double-tap for the live screen.")
            .accessibilityIdentifier("livebar")
        }
    }
}

/// Hides the status bar while the dark live screen is up. Reads the spring on its own
/// so the per-frame updates stay local.
struct StatusBarVisibility: View {
    let live: SpringValue

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .statusBarHidden(live.value < 0.5)
    }
}
