import SwiftUI

/// Native sheets (G8: drag, detents, velocity, rubber-band and interruption are the
/// system's), dressed in the prototype's bone and 28 pt corners.
struct SheetHost: View {
    let route: SheetRoute

    var body: some View {
        Group {
            switch route {
            case .quickAdd(let switching):
                QuickAddSheet(switching: switching)
            case .backfill(let from, let to):
                BackfillSheet(from: from, to: to)
            case .detail(let id):
                EntryDetailSheet(entryID: id)
            case .share:
                ShareCaptureSheet()
            case .you:
                YouSheet()
            }
        }
        .presentationBackground(Palette.bone)
        .presentationCornerRadius(Metrics.sheetRadius)
        .presentationDragIndicator(.visible)
        .overlay(alignment: .bottom) {
            ToastLayer(bottom: 36)
        }
        .tint(Palette.clay)
    }
}

/// A sheet exactly as tall as its content (the prototype's sheets size to content),
/// optionally able to expand to `.large` — e.g. when the keyboard comes up.
struct FittedSheet<Content: View>: View {
    var canExpand = false
    @Binding var expanded: Bool
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 480

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 24)
                .padding(.bottom, 28)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newValue in
                    height = newValue
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .presentationDetents(canExpand ? [.height(height), .large] : [.height(height)], selection: detent)
    }

    private var detent: Binding<PresentationDetent> {
        Binding(
            get: { expanded && canExpand ? .large : .height(height) },
            set: { expanded = $0 == .large }
        )
    }
}
