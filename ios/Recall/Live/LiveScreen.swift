import PhotosUI
import RecallCore
import SwiftUI

/// The v1 tracking screen, kept exactly, demoted to the expanded state of the live bar.
/// Tracks the finger 1:1; drag down anywhere to dismiss (G7).
struct LiveScreenLayer: View {
    let live: SpringValue
    let size: CGSize
    let insets: EdgeInsets
    @State private var dragStart: Double?

    var body: some View {
        let p = live.value
        if p < 0.999 {
            LiveScreenContent(live: live, insets: insets)
                .frame(width: size.width, height: size.height)
                .offset(y: CGFloat(max(0, p)) * size.height)
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if dragStart == nil { dragStart = live.value }
                            let start = dragStart ?? 0
                            live.set(min(1, max(0, start + Double(value.translation.height / size.height))))
                        }
                        .onEnded { value in
                            dragStart = nil
                            let velocity = Double(value.velocity.height / size.height)
                            if Motion.project(live.value, velocity: velocity) > 0.4 {
                                live.animate(to: 1, velocity: velocity)
                                Haptics.tap()
                            } else {
                                live.animate(to: 0, velocity: velocity)
                            }
                        }
                )
        }
    }
}

private struct LiveScreenContent: View {
    @Environment(AppStore.self) private var store
    let live: SpringValue
    let insets: EdgeInsets

    @State private var askNote = false
    @State private var noteText = ""
    @State private var pickPhoto = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Palette.liveField
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 38, height: 4)
                    .padding(.bottom, 26)
                HStack(spacing: 8) {
                    PulsingDot(size: 9, ring: 4, ringColor: Palette.clay.opacity(0.25))
                    Text("TRACKING NOW")
                        .font(.mono(11.5))
                        .tracking(1.1)
                        .foregroundStyle(Palette.liveClayText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 16)
                if let entry = store.liveEntry {
                    middle(entry)
                }
                Spacer(minLength: 16)
                Text(notesLine)
                    .font(.mono(10.5))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(minHeight: 14)
                    .padding(.bottom, 12)
                HStack(spacing: 12) {
                    Button("Switch") { switchBlock() }
                        .buttonStyle(LiveButtonStyle(filled: false))
                    Button("Stop block") { stopBlock() }
                        .buttonStyle(LiveButtonStyle(filled: true))
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, insets.top + 10)
            .padding(.bottom, max(34, insets.bottom + 14))
        }
        .environment(\.colorScheme, .dark)
        .alert("Add a thought", isPresented: $askNote) {
            TextField("what's on your mind?", text: $noteText)
            Button("Add") {
                store.addNoteToLive(noteText)
                noteText = ""
            }
            Button("Cancel", role: .cancel) { noteText = "" }
        }
        .photosPicker(isPresented: $pickPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.attachPhotoToLive(data)
                }
            }
        }
    }

    private func middle(_ entry: LogEntry) -> some View {
        VStack(spacing: 0) {
            TimelineView(.periodic(from: entry.start, by: 1)) { context in
                Text(Fmt.clock(context.date.timeIntervalSince(entry.start)))
                    .font(.mono(64, medium: true, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .tracking(0.5)
                    .foregroundStyle(Palette.liveText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Text(entry.title)
                .font(.serif(26, relativeTo: .title))
                .foregroundStyle(Palette.liveText)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Text([entry.place.map { "@ \($0)" }, "started \(store.hhmm(entry.start))"]
                .compactMap { $0 }
                .joined(separator: " · "))
                .font(.mono(11.5))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.top, 8)
            HStack(spacing: 7) {
                chip("+ note") { askNote = true }
                chip("+ media") { store.open(.share) }
                chip("+ photo") { pickPhoto = true }
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mono(10.5))
                .foregroundStyle(Color.white.opacity(0.78))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.95))
    }

    private var notesLine: String {
        guard let entry = store.liveEntry else { return "" }
        let photos = entry.photos?.count ?? 0
        return [entry.note, photos > 0 ? "\(photos) photo\(photos == 1 ? "" : "s")" : nil]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
    }

    private func switchBlock() {
        live.animate(to: 1)
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            store.open(.quickAdd(switching: true))
        }
    }

    private func stopBlock() {
        store.stopLive()
        live.animate(to: 1)
    }
}

private struct LiveButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sans(15, filled ? .medium : .regular)
            .foregroundStyle(filled ? Color(hex: 0x1C1B19) : Palette.liveText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(filled ? Palette.liveText : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(filled ? Color.clear : Color.white.opacity(0.25), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(SpringPreset.snappy.animation, value: configuration.isPressed)
    }
}

/// The live dot: clay with a glow ring that breathes (off under Reduce Motion).
struct PulsingDot: View {
    var size: CGFloat = 10
    var ring: CGFloat = 4
    var ringColor: Color = Palette.clayWash
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        Circle()
            .fill(Palette.clay)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(ringColor)
                    .opacity(breathe ? 0.5 : 1)
                    .padding(-(breathe ? ring + 3 : ring))
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
    }
}
