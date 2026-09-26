import SwiftUI

/// TODAY · ARCHIVE · ⊕ · INSIGHTS · YOU — mono labels on bone 88% + blur, hairline on top.
/// YOU opens the You sheet rather than a tab (settings are visited monthly).
struct TabBar: View {
    @Environment(AppStore.self) private var store
    let bottomInset: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            tab("TODAY", .today)
            tab("ARCHIVE", .archive)
            Color.clear
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            tab("INSIGHTS", .insights)
            Button {
                store.open(.you)
            } label: {
                label("YOU", active: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tab.you")
        }
        .frame(height: 44)
        .padding(.top, 14)
        .padding(.bottom, bottomInset)
        .background {
            ZStack(alignment: .top) {
                Rectangle().fill(.ultraThinMaterial)
                Palette.bone.opacity(0.88)
                Palette.hair.frame(height: 1)
            }
        }
    }

    private func tab(_ title: String, _ target: AppTab) -> some View {
        let active = store.tab == target
        return Button {
            store.select(target)
        } label: {
            label(title, active: active)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(title.lowercased())")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func label(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.mono(10))
            .tracking(1)
            .foregroundStyle(active ? Palette.ink : Palette.ink3)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.18), value: active)
    }
}
