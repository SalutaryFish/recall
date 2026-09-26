import Observation
import QuartzCore
import SwiftUI
import UIKit

/// The three spring classes from Recall-UX.md §7.
enum SpringPreset {
    case snappy, standard, gentle

    var stiffness: Double {
        switch self {
        case .snappy: return 400
        case .standard: return 260
        case .gentle: return 180
        }
    }

    var damping: Double {
        switch self {
        case .snappy: return 32
        case .standard: return 26
        case .gentle: return 24
        }
    }

    var animation: Animation {
        .interpolatingSpring(mass: 1, stiffness: stiffness, damping: damping)
    }
}

enum Motion {
    /// Seconds of velocity look-ahead: commit decisions use where a gesture was
    /// heading, not where the finger stopped (§5.1).
    static let lookAhead = 0.12

    static func project(_ position: Double, velocity: Double) -> Double {
        position + velocity * lookAhead
    }

    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    /// `withAnimation` that collapses to an instant change under Reduce Motion.
    static func animate(_ preset: SpringPreset, _ body: () -> Void) {
        if reduceMotion {
            body()
        } else {
            withAnimation(preset.animation, body)
        }
    }
}

/// A real spring integrator driven by CADisplayLink (120 Hz on ProMotion).
/// Unlike an animation curve it always knows its presented position and velocity,
/// so a finger can catch a moving element mid-flight and carry on from exactly
/// where it is (§5.1 "interruptibility").
@Observable
final class SpringValue {
    private(set) var value: Double
    @ObservationIgnored private(set) var velocity: Double = 0
    @ObservationIgnored private var target: Double
    @ObservationIgnored private var preset: SpringPreset
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastTimestamp: CFTimeInterval = 0
    @ObservationIgnored var onRest: (() -> Void)?
    private let precision: Double

    /// `precision` is the rest threshold in the value's own units (points, or a 0–1 fraction).
    init(_ value: Double, preset: SpringPreset = .standard, precision: Double = 0.5) {
        self.value = value
        self.target = value
        self.preset = preset
        self.precision = precision
    }

    var isAnimating: Bool { link != nil }
    var restingTarget: Double { target }

    /// Direct manipulation: stop wherever it is and follow the finger.
    func set(_ newValue: Double) {
        stop()
        target = newValue
        velocity = 0
        if value != newValue { value = newValue }
    }

    /// Spring toward `newTarget`, optionally carrying a gesture's velocity (units per second).
    func animate(to newTarget: Double, velocity newVelocity: Double? = nil, preset newPreset: SpringPreset? = nil) {
        target = newTarget
        if let newVelocity { velocity = newVelocity }
        if let newPreset { preset = newPreset }
        if Motion.reduceMotion {
            snap(to: newTarget)
            onRest?()
            return
        }
        start()
    }

    func snap(to newValue: Double) {
        stop()
        target = newValue
        velocity = 0
        if value != newValue { value = newValue }
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    private func start() {
        guard link == nil else { return }
        let proxy = DisplayLinkProxy { [weak self] link in
            guard let self else {
                link.invalidate()
                return
            }
            self.step(link)
        }
        let newLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
        newLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        newLink.add(to: .main, forMode: .common)
        link = newLink
        lastTimestamp = 0
    }

    private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let elapsed = lastTimestamp == 0 ? link.duration : now - lastTimestamp
        lastTimestamp = now
        var remaining = min(max(elapsed, 0), 0.064)
        var x = value
        var v = velocity
        let k = preset.stiffness
        let c = preset.damping
        // fixed sub-steps keep a stiff spring stable across a dropped frame
        while remaining > 0 {
            let h = min(1.0 / 240, remaining)
            remaining -= h
            let force = -k * (x - target) - c * v
            v += force * h
            x += v * h
        }
        velocity = v
        if abs(v) < precision * 4 && abs(x - target) < precision {
            velocity = 0
            value = target
            stop()
            onRest?()
        } else {
            value = x
        }
    }
}

/// CADisplayLink retains its target; this keeps it from retaining the spring.
final class DisplayLinkProxy: NSObject {
    private let tick: (CADisplayLink) -> Void

    init(_ tick: @escaping (CADisplayLink) -> Void) {
        self.tick = tick
    }

    @objc func fire(_ link: CADisplayLink) {
        tick(link)
    }
}

/// Rubber-banding past a limit (drag beyond a rail, a sheet's end, a day that doesn't exist yet).
func rubberBand(_ x: Double, limit: Double, factor: Double = 0.35) -> Double {
    guard abs(x) > limit else { return x }
    let over = abs(x) - limit
    return (limit + over * factor) * (x < 0 ? -1 : 1)
}
