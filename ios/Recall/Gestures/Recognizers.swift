import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// A horizontal-only pan with the spec's directional intent lock (§5.1): if the
/// first few points of movement are mostly vertical it fails immediately, so the
/// scroll view gets the gesture and a diagonal scroll never half-opens a row.
final class HorizontalPanRecognizer: UIPanGestureRecognizer {
    private var origin: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if origin == nil, let touch = touches.first {
            origin = touch.location(in: view)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible, let origin, let touch = touches.first {
            let p = touch.location(in: view)
            let dx = abs(p.x - origin.x)
            let dy = abs(p.y - origin.y)
            if max(dx, dy) > 6 && dy > dx {
                state = .failed
                return
            }
        }
        super.touchesMoved(touches, with: event)
    }

    override func reset() {
        super.reset()
        origin = nil
    }
}

/// Swipe rows left/right (G3/G4). Reports horizontal translation and velocity (pt, pt/s).
struct HorizontalSwipeGesture: UIGestureRecognizerRepresentable {
    var isEnabled = true
    var onBegan: () -> Void
    var onChanged: (_ translation: CGFloat, _ velocity: CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> HorizontalPanRecognizer {
        let recognizer = HorizontalPanRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: HorizontalPanRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: HorizontalPanRecognizer, context: Context) {
        let view = recognizer.view
        let translation = recognizer.translation(in: view).x
        let velocity = recognizer.velocity(in: view).x
        switch recognizer.state {
        case .began:
            onBegan()
            onChanged(translation, velocity)
        case .changed:
            onChanged(translation, velocity)
        case .ended:
            onEnded(translation, velocity)
        case .cancelled, .failed:
            onEnded(translation, 0)
        default:
            break
        }
    }
}

final class LiftRecognizer: UILongPressGestureRecognizer {
    var origin: CGPoint = .zero
}

/// Long-press to lift a row, then drag to re-time it (G5). The long press holds
/// off the scroll view until it fires; moving more than 8 pt first cancels it.
struct LiftGesture: UIGestureRecognizerRepresentable {
    var isEnabled = true
    var minimumDuration: TimeInterval = 0.35
    var onBegan: () -> Void
    var onChanged: (_ translation: CGSize) -> Void
    var onEnded: (_ translation: CGSize, _ cancelled: Bool) -> Void

    func makeUIGestureRecognizer(context: Context) -> LiftRecognizer {
        let recognizer = LiftRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = 8
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: LiftRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: LiftRecognizer, context: Context) {
        let point = recognizer.location(in: nil)
        let translation = CGSize(width: point.x - recognizer.origin.x, height: point.y - recognizer.origin.y)
        switch recognizer.state {
        case .began:
            recognizer.origin = point
            onBegan()
        case .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation, false)
        case .cancelled, .failed:
            onEnded(translation, true)
        default:
            break
        }
    }
}
