import SwiftUI
import UIKit

/// Newsreader (editorial voice) + IBM Plex Mono (the transcript), bundled via UIAppFonts.
/// PostScript names read from the font files with fontTools.
enum Typeface {
    static let serif = "Newsreader16pt-Regular"
    static let serifItalic = "Newsreader16pt-Italic"
    static let mono = "IBMPlexMono-Regular"
    static let monoMedium = "IBMPlexMono-Medium"
    static let all = [serif, serifItalic, mono, monoMedium]

    /// If a font ever fails to register, fall back to the system serif/mono rather than Helvetica.
    static let isAvailable: Bool = all.allSatisfy { UIFont(name: $0, size: 12) != nil }
}

extension Font {
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        Typeface.isAvailable
            ? .custom(Typeface.serif, size: size, relativeTo: style)
            : .system(size: size, design: .serif)
    }

    static func serifItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        Typeface.isAvailable
            ? .custom(Typeface.serifItalic, size: size, relativeTo: style)
            : .system(size: size, design: .serif).italic()
    }

    static func mono(_ size: CGFloat, medium: Bool = false, relativeTo style: Font.TextStyle = .footnote) -> Font {
        Typeface.isAvailable
            ? .custom(medium ? Typeface.monoMedium : Typeface.mono, size: size, relativeTo: style)
            : .system(size: size, weight: medium ? .medium : .regular, design: .monospaced)
    }
}

/// System sans at the prototype's pixel size, still scaling with Dynamic Type.
struct SansFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    func sans(_ size: CGFloat, _ weight: Font.Weight = .regular,
              relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(SansFont(size: size, weight: weight, relativeTo: style))
    }
}
