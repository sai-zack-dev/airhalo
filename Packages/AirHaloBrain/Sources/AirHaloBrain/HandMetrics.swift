import Foundation

/// Measurements of one hand that the gesture rules are written in terms of.
public struct HandMetrics: Sendable, Equatable {
    /// Wrist to middle-finger knuckle, in units. Used to make every threshold distance-independent.
    public var scale: Double
    /// Average of the wrist and the four knuckles. It barely moves when you pinch,
    /// which is why the pointer follows it instead of a fingertip.
    public var palmCenter: Vec2
    /// Thumb tip to index tip, in hand scales.
    public var indexPinch: Double
    /// Thumb tip to middle tip, in hand scales.
    public var middlePinch: Double
    /// Midpoint of the thumb and index tips (where a pinch "is").
    public var pinchPoint: Vec2
    /// For each finger (index, middle, ring, little): wrist→tip divided by wrist→knuckle.
    /// About 1.9 when straight, about 0.9 when curled.
    public var fingerExtension: [Double]

    public init?(hand: Hand, minConfidence: Double = 0.3) {
        let required: [Joint] = [.wrist, .indexMCP, .middleMCP, .ringMCP, .littleMCP, .thumbTip, .indexTip, .middleTip]
        guard required.allSatisfy({ hand.confidence($0) >= minConfidence }) else { return nil }

        let wrist = hand[.wrist]
        let scale = wrist.distance(to: hand[.middleMCP])
        guard scale > 0.02 else { return nil }
        self.scale = scale

        let palmJoints: [Joint] = [.wrist, .indexMCP, .middleMCP, .ringMCP, .littleMCP]
        palmCenter = palmJoints.reduce(Vec2.zero) { $0 + hand[$1] } / Double(palmJoints.count)

        indexPinch = hand[.thumbTip].distance(to: hand[.indexTip]) / scale
        middlePinch = hand[.thumbTip].distance(to: hand[.middleTip]) / scale
        pinchPoint = (hand[.thumbTip] + hand[.indexTip]) / 2

        fingerExtension = Finger.allCases.map { finger in
            let knuckle = wrist.distance(to: hand[finger.mcp])
            guard knuckle > 1e-6, hand.confidence(finger.tip) >= minConfidence else { return 1.0 }
            return wrist.distance(to: hand[finger.tip]) / knuckle
        }
    }

    public func isExtended(_ finger: Finger, settings: BrainSettings) -> Bool {
        fingerExtension[finger.rawValue] > settings.fingerExtended
    }

    public func isFolded(_ finger: Finger, settings: BrainSettings) -> Bool {
        fingerExtension[finger.rawValue] < settings.fingerFolded
    }
}
