import SwiftUI

/// The ink toast. Mounted at the root and inside every sheet, so it is never hidden behind one.
struct ToastLayer: View {
    @Environment(AppStore.self) private var store
    var bottom: CGFloat = 150

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if let toast = store.toast {
                Text(toast.text)
                    .font(.mono(11))
                    .tracking(0.5)
                    .foregroundStyle(Palette.bone)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 28)
                    .transition(.opacity.combined(with: .offset(y: 14)))
                    .id(toast.id)
                    .accessibilityIdentifier("toast")
            }
        }
        .padding(.bottom, bottom)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.22), value: store.toast)
        .allowsHitTesting(false)
        .task(id: store.toast?.id) {
            guard let toast = store.toast else { return }
            try? await Task.sleep(for: .seconds(toast.duration))
            if store.toast?.id == toast.id { store.toast = nil }
        }
    }
}
