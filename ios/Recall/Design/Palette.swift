import RecallCore
import SwiftUI
import UIKit

extension UIColor {
    convenience nonisolated init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    nonisolated init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    /// A colour that follows the interface style, including the in-app theme override.
    nonisolated static func adaptive(_ light: UInt32, _ dark: UInt32,
                                     lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

/// Tokens from Recall-UX.md §4 / the prototype's `:root` and `.dark` blocks.
enum Palette {
    static let bone = Color.adaptive(0xFAFAF9, 0x141311)
    static let card = Color.adaptive(0xFFFFFF, 0x1E1D1A)
    static let wash = Color.adaptive(0xF0EEE9, 0x262420)
    static let wash2 = Color.adaptive(0xE7E4DD, 0x302D28)
    /// 16.48:1 on bone (dark 16.75:1).
    static let ink = Color.adaptive(0x1C1B19, 0xF5F3EF)
    /// 7.25:1 (dark 8.98:1).
    static let ink2 = Color.adaptive(0x56544E, 0xB8B4AB)
    /// 5.10:1 — timestamps (dark 6.78:1).
    static let ink3 = Color.adaptive(0x6E6B63, 0xA09C93)
    static let hair = Color.adaptive(0x000000, 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.10)
    static let hair2 = Color.adaptive(0x000000, 0xFFFFFF, lightAlpha: 0.14, darkAlpha: 0.18)
    /// Live accent — fills and dots only.
    static let clay = Color(hex: 0xB5734F)
    /// Clay-coloured text (5.13:1 light, 7.40:1 dark).
    static let clayInk = Color.adaptive(0x9A5B34, 0xD19770)
    static let clayWash = Color.adaptive(0xB5734F, 0xB5734F, lightAlpha: 0.12, darkAlpha: 0.18)
    static let dot = Color.adaptive(0xCFCCC4, 0x4A463F)
    static let shadowCard = Color.adaptive(0x000000, 0x000000, lightAlpha: 0.04, darkAlpha: 0.30)

    static let toneSleep = Color.adaptive(0xE3DFD7, 0x2E2B26)
    static let toneLife = Color.adaptive(0xC6C0B4, 0x4A453D)
    static let toneFocus = Color.adaptive(0x575046, 0x8E867A)
    static let toneSocial = Color.adaptive(0x8E867A, 0x655E53)
    static let toneMedia = Color(hex: 0xB5734F)
    static let toneMediaBackground = Color.adaptive(0xDCBBA6, 0x7A543C)

    static func tone(_ category: EntryCategory) -> Color {
        switch category {
        case .sleep: return toneSleep
        case .life: return toneLife
        case .focus: return toneFocus
        case .social: return toneSocial
        case .media: return toneMedia
        case .mediaBackground: return toneMediaBackground
        }
    }

    /// Heatmap: darker = more of the day captured (lighter in dark mode).
    static let heat: [Color] = [
        Color.adaptive(0xEEEBE5, 0x221F1B),
        Color.adaptive(0xD8D3C9, 0x332F28),
        Color.adaptive(0xB9B2A4, 0x4A453C),
        Color.adaptive(0x8E867A, 0x6B6459),
        Color.adaptive(0x5E574C, 0x948C7E),
    ]

    // swipe rails
    static let railEdit = Color(hex: 0x6E6B63)
    static let railSplit = Color(hex: 0x8E867A)
    static let railDelete = Color(hex: 0x9A4B3A)

    // the live screen is always dark
    static let liveField = Color(hex: 0x151412)
    static let liveText = Color(hex: 0xFAFAF9)
    static let liveClayText = Color(hex: 0xD19770)

    static let scrim = Color(hex: 0x1C1B19, alpha: 0.28)
}
