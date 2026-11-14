import Foundation

/// The hand shapes the gesture engine cares about, for one frame.
public struct Pose: Sendable, Equatable {
    /// All four fingers straight.
    public var openPalm = false
    /// All four fingers curled.
    public var fist = false
    /// Index and middle straight, ring and little curled (the scroll pose).
    public var twoFinger = false
    /// Thumb touching index tip.
    public var indexPinched = false
    /// Thumb touching middle tip (right click).
    public var middlePinched = false

    public init() {}
}

/// Turns hand metrics into a `Pose`. Keeps pinch state between frames so a pinch
/// needs to open clearly (`pinchOpen`) before it counts as released (hysteresis).
public struct PoseClassifier: Sendable {
    private var indexPinched = false
    private var middlePinched = false

    public init() {}

    public mutating func reset() {
        indexPinched = false
        middlePinched = false
    }

    public mutating func classify(_ m: HandMetrics, settings s: BrainSettings) -> Pose {
        // Index pinch wins over middle pinch when the thumb is near both.
        if indexPinched {
            if m.indexPinch > s.pinchOpen { indexPinched = false }
        } else if m.indexPinch < s.pinchClose, !middlePinched {
            indexPinched = true
        }

        if middlePinched {
            if m.middlePinch > s.pinchOpen { middlePinched = false }
        } else if !indexPinched, m.middlePinch < s.pinchClose, m.indexPinch > s.pinchClose * 1.5 {
            middlePinched = true
        }

        var pose = Pose()
        pose.indexPinched = indexPinched
        pose.middlePinched = middlePinched

        let extended = Finger.allCases.map { m.isExtended($0, settings: s) }
        let folded = Finger.allCases.map { m.isFolded($0, settings: s) }
        let anyPinch = indexPinched || middlePinched

        pose.openPalm = !anyPinch && extended.allSatisfy { $0 }
        pose.fist = !anyPinch && folded.allSatisfy { $0 }
        pose.twoFinger = !anyPinch && extended[0] && extended[1] && folded[2] && folded[3]
        return pose
    }
}
