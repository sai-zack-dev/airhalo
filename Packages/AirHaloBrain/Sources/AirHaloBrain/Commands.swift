import Foundation

public enum MouseButton: String, Sendable, Codable {
    case left, right
}

public enum ScrollPhase: String, Sendable, Codable {
    case began, changed, ended
    /// Coasting after the hand let go, like trackpad momentum.
    case momentum
    case momentumEnded
}

public enum ZoomDirection: String, Sendable, Codable {
    case zoomIn, zoomOut
}

/// Which Space to go to (same as ⌃← / ⌃→).
public enum SpaceDirection: String, Sendable, Codable {
    case left, right
}

/// What the brain asks the platform layer to do.
public enum Command: Sendable, Equatable {
    /// Move the pointer by this many screen points.
    case move(dx: Double, dy: Double)
    /// Move the pointer to a position on the main screen, each axis 0...1 from the top-left.
    case moveTo(x: Double, y: Double)
    case buttonDown(MouseButton, clickCount: Int)
    case buttonUp(MouseButton, clickCount: Int)
    /// Scroll content by this many points. Positive dy shows content further up the page
    /// (like a scroll wheel turned toward you), positive dx shows content further left.
    case scroll(dx: Double, dy: Double, phase: ScrollPhase)
    case zoom(ZoomDirection)
    case switchSpace(SpaceDirection)
}

/// What the halo cursor should look like.
public struct HaloState: Sendable, Equatable {
    public enum Mode: String, Sendable {
        case hidden
        /// Open palm seen, waiting for the engage hold to finish.
        case arming
        case hover
        case pressed
        case dragging
        case rightPressed
        case scrolling
        case zooming
    }

    public var mode: Mode
    /// 0 = fingers apart, 1 = pinch closed. Drives the ring shrinking.
    public var pinchProgress: Double
    /// 0...1 while arming.
    public var armingProgress: Double

    public init(mode: Mode = .hidden, pinchProgress: Double = 0, armingProgress: Double = 0) {
        self.mode = mode
        self.pinchProgress = pinchProgress
        self.armingProgress = armingProgress
    }

    public static let hidden = HaloState()
}

public struct EngineOutput: Sendable, Equatable {
    public var commands: [Command]
    public var halo: HaloState

    public init(commands: [Command] = [], halo: HaloState = .hidden) {
        self.commands = commands
        self.halo = halo
    }
}
