import UIKit

/// One call per threshold crossing, never repeated while held (§5.1).
/// Mapped from the prototype's vibration lengths.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()

    static func prepare() {
        light.prepare()
        medium.prepare()
        selection.prepare()
    }

    /// Threshold crossed, arc item under the thumb, 5-minute snap step (5–6 ms).
    static func tick() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// Sheet opened, row snapped open, entry kept (8 ms).
    static func tap() {
        light.impactOccurred()
        light.prepare()
    }

    /// Block started or stopped, density changed, day paged (10–12 ms).
    static func thud() {
        medium.impactOccurred()
        medium.prepare()
    }

    /// Row lifted, frequents arc raised (14 ms).
    static func lift() {
        rigid.impactOccurred()
        rigid.prepare()
    }
}
