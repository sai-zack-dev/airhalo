import Foundation

/// Converts hand movement into pointer movement.
public enum PointerMapper {
    /// Relative ("trackpad") mode: slow movements are precise, fast movements cover the screen.
    /// - Parameters:
    ///   - delta: palm movement in units since the last frame
    ///   - dt: seconds since the last frame
    /// - Returns: pointer movement in screen points
    public static func relativeDelta(_ delta: Vec2, dt: Double, settings s: BrainSettings) -> Vec2 {
        let speed = delta.length / max(dt, 1e-3)
        let t = smoothstep(s.accelLowSpeed, s.accelHighSpeed, speed)
        let gain = (s.minGain + (s.maxGain - s.minGain) * t) * s.sensitivity
        return delta * gain
    }

    /// Absolute mode: where the palm is inside `absoluteZone` is where the pointer goes.
    /// - Returns: position on screen, each axis 0...1 from the top-left
    public static func absolutePosition(_ palm: Vec2, aspect: Double, settings s: BrainSettings) -> Vec2 {
        let zone = s.absoluteZone
        let fx = (palm.x / max(aspect, 1e-6) - zone.x) / max(zone.width, 1e-6)
        let fy = (palm.y - zone.y) / max(zone.height, 1e-6)
        return Vec2(min(max(fx, 0), 1), min(max(fy, 0), 1))
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 > edge0 else { return x >= edge1 ? 1 : 0 }
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
