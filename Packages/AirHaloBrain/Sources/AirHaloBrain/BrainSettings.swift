import Foundation

public enum PointerMode: String, Sendable, Codable, CaseIterable {
    /// Like a trackpad: hand movement moves the pointer by a relative amount, with acceleration.
    case relative
    /// Like pointing: a box in the camera image maps straight onto the screen.
    case absolute
}

/// A rectangle in fractions of the camera image (0...1 on both axes, top-left origin).
public struct ZoneRect: Sendable, Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Every threshold and tuning value used by the brain.
///
/// Distance units: "units" are fractions of the camera image height (see `HandFrame`).
/// "Hand scales" are multiples of the wrist-to-middle-knuckle distance, which makes
/// thresholds independent of how far the hand is from the camera.
public struct BrainSettings: Sendable, Codable, Equatable {
    // MARK: Pointer
    public var pointerMode: PointerMode = .relative
    /// User-facing speed multiplier.
    public var sensitivity: Double = 1.0
    /// Screen points per unit of hand movement when moving slowly (precise).
    public var minGain: Double = 900
    /// Screen points per unit when moving fast (crossing the screen).
    public var maxGain: Double = 3600
    /// Hand speed (units/s) at or below which `minGain` applies.
    public var accelLowSpeed: Double = 0.05
    /// Hand speed (units/s) at or above which `maxGain` applies.
    public var accelHighSpeed: Double = 0.8
    /// Part of the camera image that maps onto the screen in absolute mode.
    public var absoluteZone = ZoneRect(x: 0.2, y: 0.15, width: 0.6, height: 0.6)

    // MARK: Smoothing
    /// 0 = most responsive, 1 = smoothest.
    public var smoothing: Double = 0.5
    /// One-Euro beta: how quickly smoothing relaxes as the hand speeds up.
    public var filterBeta: Double = 4

    // MARK: Engage / disengage
    /// How long an open palm must be held before the pointer follows the hand.
    public var engageHold: Double = 0.3
    /// How long a fist must be held to stop.
    public var fistDisengageHold: Double = 0.5
    /// How long the hand can be missing before AirHalo disengages.
    public var lostHandTimeout: Double = 1.0
    /// Joints below this tracker confidence are treated as missing.
    public var minJointConfidence: Double = 0.3

    // MARK: Pinch / click / drag
    /// Thumb-to-fingertip distance (hand scales) below which a pinch closes.
    public var pinchClose: Double = 0.25
    /// Distance above which a closed pinch opens again. Larger than `pinchClose` so it doesn't flicker.
    public var pinchOpen: Double = 0.40
    /// The pointer stays still for this long after a pinch closes, so clicks land where you aimed.
    public var clickFreeze: Double = 0.12
    /// Holding a pinch this long turns it into a drag.
    public var dragHoldTime: Double = 0.30
    /// Moving the hand this far (units) while pinched also starts a drag.
    public var dragDeadzone: Double = 0.02
    /// Max time between pinches for a double click. The app sets this from the system setting.
    public var doubleClickInterval: Double = 0.5
    /// Max pointer travel (points) between the clicks of a double click.
    public var doubleClickRadius: Double = 6

    // MARK: Finger poses
    /// A finger counts as extended when wrist→tip is this many times wrist→knuckle.
    public var fingerExtended: Double = 1.5
    /// A finger counts as folded below this ratio.
    public var fingerFolded: Double = 1.3

    // MARK: Scroll
    public var scrollEnabled = true
    /// How long the two-finger pose must be held to start scrolling.
    public var scrollHold: Double = 0.15
    /// Points scrolled per unit of hand movement.
    public var scrollGain: Double = 2500
    /// Content follows the hand, like natural scrolling on a trackpad.
    public var naturalScroll = true
    /// How long scrolling coasts after letting go (0 turns momentum off).
    public var scrollMomentum: Double = 0.35

    // MARK: Zoom
    public var zoomEnabled = true
    /// Fractional change in the distance between both hands that triggers one zoom step.
    public var zoomStep: Double = 0.18

    // MARK: Switch Space
    public var swipeEnabled = true
    /// A flick must travel at least this far (hand scales)...
    public var swipeMinTravel: Double = 1.6
    /// ...within this many seconds.
    public var swipeWindow: Double = 0.25
    /// Minimum average speed of the flick (hand scales per second).
    public var swipeMinSpeed: Double = 3.0
    /// Wait this long before another Space switch.
    public var swipeCooldown: Double = 0.6

    public init() {}

    /// One-Euro minimum cutoff derived from the smoothing slider.
    public var filterMinCutoff: Double {
        let s = min(max(smoothing, 0), 1)
        return 3.0 + (0.3 - 3.0) * s
    }
}
