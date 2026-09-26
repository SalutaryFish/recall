import Observation
import RecallCore
import SwiftUI

/// The frequents arc (§6.4): four frequents fanned over 124° above ⊕, sized for a right thumb.
@Observable
final class ArcModel {
    var isOpen = false
    var hot: Int?
    var items: [Frequent] = []
    var center: CGPoint = .zero

    static let radius: CGFloat = 100

    func point(_ index: Int) -> CGPoint {
        let n = items.count
        let degrees = n > 1 ? 152 + (28 - 152) * Double(index) / Double(n - 1) : 90
        let a = degrees * .pi / 180
        return CGPoint(x: center.x + cos(a) * Self.radius, y: center.y - sin(a) * Self.radius)
    }
}

/// ⊕ — tap: quick-add sheet. Hold 280 ms: the arc rises; slide to a frequent and release
/// to start it; release on ⊕ or away from the arc commits nothing (G6).
struct CaptureButton: View {
    @Environment(AppStore.self) private var store
    let arc: ArcModel
    let center: CGPoint

    @State private var pressing = false
    @State private var travelled: CGFloat = 0
    @State private var armTask: Task<Void, Never>?

    var body: some View {
        Circle()
            .fill(Palette.ink)
            .frame(width: 56, height: 56)
            .overlay {
                Text("+")
                    .font(.system(size: 29, weight: .thin))
                    .foregroundStyle(Palette.bone)
                    .offset(y: -2)
                    .rotationEffect(.degrees(arc.isOpen ? 45 : 0))
                    .animation(.easeOut(duration: 0.2), value: arc.isOpen)
            }
            .shadow(color: .black.opacity(0.22), radius: 9, x: 0, y: 6)
            .scaleEffect(pressing && !arc.isOpen ? 0.94 : 1)
            .animation(SpringPreset.snappy.animation, value: pressing)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("chrome"))
                    .onChanged { value in changed(value) }
                    .onEnded { value in ended(value) }
            )
            .accessibilityElement()
            .accessibilityLabel("Log something")
            .accessibilityHint("Opens quick add. Your frequents are in the actions.")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("capture")
            .accessibilityAction {
                store.open(.quickAdd(switching: false))
            }
            .accessibilityActions {
                ForEach(store.topFrequents(4)) { frequent in
                    Button("Start \(frequent.name)") {
                        store.startBlock(frequent.name, category: frequent.category)
                    }
                }
            }
    }

    private func changed(_ value: DragGesture.Value) {
        if !pressing {
            pressing = true
            travelled = 0
            armTask?.cancel()
            armTask = Task {
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled, pressing else { return }
                openArc()
            }
        }
        travelled = max(travelled, (value.translation.width * value.translation.width
                + value.translation.height * value.translation.height).squareRoot())
        if arc.isOpen { track(value.location) }
    }

    private func ended(_ value: DragGesture.Value) {
        armTask?.cancel()
        armTask = nil
        pressing = false
        if arc.isOpen {
            let pick = arc.hot.map { arc.items[$0] }
            withAnimation(.easeOut(duration: 0.16)) { arc.isOpen = false }
            arc.hot = nil
            if let pick { store.startBlock(pick.name, category: pick.category) }
        } else if travelled < 10 {
            store.open(.quickAdd(switching: false))
        }
    }

    private func openArc() {
        arc.items = store.topFrequents(4)
        arc.center = center
        arc.hot = nil
        withAnimation(.easeOut(duration: 0.16)) { arc.isOpen = true }
        Haptics.lift()
    }

    private func track(_ location: CGPoint) {
        var best: Int?
        var bestDistance: CGFloat = 76
        for index in arc.items.indices {
            let p = arc.point(index)
            let d = ((location.x - p.x) * (location.x - p.x) + (location.y - p.y) * (location.y - p.y)).squareRoot()
            if d < bestDistance {
                bestDistance = d
                best = index
            }
        }
        let fromCenter = ((location.x - center.x) * (location.x - center.x)
            + (location.y - center.y) * (location.y - center.y)).squareRoot()
        if fromCenter < 44 { best = nil }
        if best != arc.hot {
            arc.hot = best
            if best != nil { Haptics.tick() }
        }
    }
}

struct ArcOverlay: View {
    let arc: ArcModel
    let size: CGSize
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.scrim
                .frame(width: size.width, height: size.height)
            Text("SLIDE TO PICK · RELEASE TO START")
                .font(.mono(10))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.75))
                .fixedSize()
                .position(x: size.width / 2, y: arc.center.y - ArcModel.radius - 46)
            ForEach(arc.items.indices, id: \.self) { index in
                let hot = arc.hot == index
                ArcItem(frequent: arc.items[index], hot: hot)
                    .scaleEffect(appeared ? (hot ? 1.16 : 1) : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.26, dampingFraction: 0.6).delay(Double(index) * 0.026), value: appeared)
                    .animation(SpringPreset.snappy.animation, value: hot)
                    .position(arc.point(index))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .transition(.opacity)
        .onAppear { appeared = true }
    }
}

private struct ArcItem: View {
    let frequent: Frequent
    let hot: Bool

    var body: some View {
        VStack(spacing: 1) {
            Text(frequent.glyph).font(.system(size: 19))
            Text(frequent.name)
                .font(.system(size: 9))
                .tracking(0.2)
                .foregroundStyle(hot ? Palette.bone : Palette.ink2)
                .lineLimit(1)
        }
        .frame(width: 66, height: 66)
        .background {
            Circle()
                .fill(hot ? Palette.ink : Palette.card)
                .shadow(color: .black.opacity(0.18), radius: 9, x: 0, y: 6)
        }
        .overlay {
            Circle().strokeBorder(hot ? Palette.ink : Palette.hair, lineWidth: 1)
        }
    }
}
