import Foundation

/// A 2D point or vector. The brain uses its own type (not CGPoint) so it has
/// no dependency on Apple graphics frameworks.
public struct Vec2: Sendable, Codable, Equatable, Hashable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public var length: Double { (x * x + y * y).squareRoot() }

    public func distance(to other: Vec2) -> Double { (self - other).length }

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    public static func / (a: Vec2, s: Double) -> Vec2 { Vec2(a.x / s, a.y / s) }
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }
}

/// The 21 hand joints, in the same order as MediaPipe Hands.
/// Apple Vision's joints map one-to-one onto this order.
public enum Joint: Int, CaseIterable, Sendable {
    case wrist = 0
    case thumbCMC, thumbMCP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip

    public static let count = 21
}

/// The four fingers (thumb handled separately).
public enum Finger: Int, CaseIterable, Sendable {
    case index, middle, ring, little

    public var mcp: Joint { Joint(rawValue: 5 + rawValue * 4)! }
    public var pip: Joint { Joint(rawValue: 6 + rawValue * 4)! }
    public var tip: Joint { Joint(rawValue: 8 + rawValue * 4)! }
}

public enum Chirality: String, Sendable, Codable {
    case left, right, unknown
}

public struct HandPoint: Sendable, Codable, Equatable {
    public var position: Vec2
    /// 0...1. Zero means the tracker did not find this joint.
    public var confidence: Double

    public init(_ position: Vec2, confidence: Double = 1) {
        self.position = position
        self.confidence = confidence
    }
}

public struct Hand: Sendable, Codable, Equatable {
    public var chirality: Chirality
    /// Exactly 21 points in `Joint` order.
    public var points: [HandPoint]

    public init(chirality: Chirality = .unknown, points: [HandPoint]) {
        precondition(points.count == Joint.count, "A hand needs \(Joint.count) points")
        self.chirality = chirality
        self.points = points
    }

    public subscript(joint: Joint) -> Vec2 { points[joint.rawValue].position }

    public func confidence(_ joint: Joint) -> Double { points[joint.rawValue].confidence }
}

/// One camera frame's worth of tracking.
///
/// Coordinate convention (identical on every platform):
/// - origin top-left, x to the right, y down
/// - the image is mirrored like a selfie, so moving your hand to your right increases x
/// - units are fractions of the image **height**: y is 0...1 and x is 0...aspect,
///   so distances are the same in both directions
public struct HandFrame: Sendable, Codable, Equatable {
    /// Seconds, monotonic.
    public var timestamp: Double
    /// Image width / height.
    public var aspect: Double
    public var hands: [Hand]

    public init(timestamp: Double, aspect: Double, hands: [Hand]) {
        self.timestamp = timestamp
        self.aspect = aspect
        self.hands = hands
    }
}
