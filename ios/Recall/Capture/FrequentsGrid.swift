import RecallCore
import SwiftUI

/// `.freq-grid`: three columns of one-tap frequents.
struct FrequentsGrid: View {
    let frequents: [Frequent]
    var showUses = true
    let onPick: (Frequent) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(frequents) { frequent in
                Button {
                    Haptics.tick()
                    onPick(frequent)
                } label: {
                    VStack(spacing: 5) {
                        Text(frequent.glyph).font(.system(size: 20))
                        Text(frequent.name)
                            .sans(11)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        if showUses {
                            Text("\(frequent.uses)×")
                                .font(.mono(9))
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .cardSurface()
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.955))
                .accessibilityIdentifier("freq.\(frequent.name)")
            }
        }
    }
}
