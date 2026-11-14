import Foundation

/// The One-Euro filter (Casiez et al., 2012): heavy smoothing when the hand is
/// nearly still (removes jitter), light smoothing when it moves fast (removes lag).
public struct OneEuroFilter: Sendable {
    /// Cutoff in Hz when still. Lower = smoother but laggier.
    public var minCutoff: Double
    /// How quickly the cutoff rises with speed.
    public var beta: Double
    /// Cutoff for the speed estimate.
    public var derivativeCutoff: Double

    private var lastValue: Double?
    private var lastDerivative: Double = 0
    private var lastTime: Double?

    public init(minCutoff: Double = 1.0, beta: Double = 0.0, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    public mutating func reset() {
        lastValue = nil
        lastDerivative = 0
        lastTime = nil
    }

    public mutating func filter(_ value: Double, at time: Double) -> Double {
        guard let previous = lastValue, let previousTime = lastTime else {
            lastValue = value
            lastTime = time
            return value
        }
        let dt = time - previousTime
        guard dt > 0 else { return previous }

        let derivative = (value - previous) / dt
        let smoothedDerivative = Self.lerp(lastDerivative, derivative, Self.alpha(cutoff: derivativeCutoff, dt: dt))
        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        let result = Self.lerp(previous, value, Self.alpha(cutoff: cutoff, dt: dt))

        lastValue = result
        lastDerivative = smoothedDerivative
        lastTime = time
        return result
    }

    static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1.0 / (2 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}

public struct OneEuroFilter2D: Sendable {
    private var x: OneEuroFilter
    private var y: OneEuroFilter

    public init(minCutoff: Double, beta: Double, derivativeCutoff: Double = 1.0) {
        x = OneEuroFilter(minCutoff: minCutoff, beta: beta, derivativeCutoff: derivativeCutoff)
        y = OneEuroFilter(minCutoff: minCutoff, beta: beta, derivativeCutoff: derivativeCutoff)
    }

    public mutating func configure(minCutoff: Double, beta: Double) {
        x.minCutoff = minCutoff
        x.beta = beta
        y.minCutoff = minCutoff
        y.beta = beta
    }

    public mutating func reset() {
        x.reset()
        y.reset()
    }

    public mutating func filter(_ point: Vec2, at time: Double) -> Vec2 {
        Vec2(x.filter(point.x, at: time), y.filter(point.y, at: time))
    }
}
