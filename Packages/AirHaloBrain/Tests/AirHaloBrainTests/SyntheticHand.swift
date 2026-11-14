import AirHaloBrain

/// Builds simple, upright fake hands for tests.
struct SyntheticHand {
    enum Pinch { case none, index, middle }
    enum FingerShape { case extended, relaxed, folded }

    var center = Vec2(0.9, 0.5)
    /// Roughly the wrist-to-knuckle distance, in units.
    var size = 0.2
    var fingers: [FingerShape] = [.extended, .extended, .extended, .extended]
    var pinch: Pinch = .none

    static func openPalm(at center: Vec2 = Vec2(0.9, 0.5)) -> SyntheticHand {
        SyntheticHand(center: center)
    }

    static func fist(at center: Vec2 = Vec2(0.9, 0.5)) -> SyntheticHand {
        SyntheticHand(center: center, fingers: [.folded, .folded, .folded, .folded])
    }

    static func relaxed(at center: Vec2 = Vec2(0.9, 0.5)) -> SyntheticHand {
        SyntheticHand(center: center, fingers: [.relaxed, .relaxed, .relaxed, .relaxed])
    }

    static func twoFinger(at center: Vec2 = Vec2(0.9, 0.5)) -> SyntheticHand {
        SyntheticHand(center: center, fingers: [.extended, .extended, .folded, .folded])
    }

    static func pinching(_ kind: Pinch = .index, at center: Vec2 = Vec2(0.9, 0.5)) -> SyntheticHand {
        SyntheticHand(center: center, pinch: kind)
    }

    func moved(to newCenter: Vec2) -> SyntheticHand {
        var copy = self
        copy.center = newCenter
        return copy
    }

    func make() -> Hand {
        let s = size
        let c = center
        func p(_ dx: Double, _ dy: Double) -> Vec2 { Vec2(c.x + dx * s, c.y + dy * s) }

        var points = [Vec2](repeating: .zero, count: Joint.count)
        points[Joint.wrist.rawValue] = p(0, 0.5)

        let knuckleX: [Double] = [-0.36, -0.12, 0.12, 0.36]
        for finger in Finger.allCases {
            let kx = knuckleX[finger.rawValue]
            let base = finger.mcp.rawValue
            points[base] = p(kx, -0.5)
            let shape = fingers[finger.rawValue]
            switch shape {
            case .extended:
                points[base + 1] = p(kx, -0.9)
                points[base + 2] = p(kx, -1.15)
                points[base + 3] = p(kx, -1.35)
            case .relaxed:
                points[base + 1] = p(kx, -0.8)
                points[base + 2] = p(kx, -0.9)
                points[base + 3] = p(kx, -0.95)
            case .folded:
                points[base + 1] = p(kx, -0.75)
                points[base + 2] = p(kx, -0.6)
                points[base + 3] = p(kx, -0.3)
            }
        }

        // Thumb, resting off to the side.
        points[Joint.thumbCMC.rawValue] = p(-0.3, 0.3)
        points[Joint.thumbMCP.rawValue] = p(-0.55, 0.05)
        points[Joint.thumbIP.rawValue] = p(-0.7, -0.15)
        points[Joint.thumbTip.rawValue] = p(-0.8, -0.35)

        switch pinch {
        case .none:
            break
        case .index:
            points[Joint.indexPIP.rawValue] = p(-0.45, -0.85)
            points[Joint.indexDIP.rawValue] = p(-0.55, -0.75)
            points[Joint.indexTip.rawValue] = p(-0.6, -0.6)
            points[Joint.thumbTip.rawValue] = p(-0.57, -0.58)
        case .middle:
            points[Joint.middlePIP.rawValue] = p(-0.2, -0.85)
            points[Joint.middleDIP.rawValue] = p(-0.35, -0.75)
            points[Joint.middleTip.rawValue] = p(-0.4, -0.65)
            points[Joint.thumbTip.rawValue] = p(-0.37, -0.63)
        }

        return Hand(chirality: .right, points: points.map { HandPoint($0) })
    }
}

/// Runs a scripted session through an engine at 30 fps.
struct Session {
    let engine: GestureEngine
    var time: Double = 0
    var commands: [Command] = []
    var lastHalo: HaloState = .hidden
    let fps: Double = 30
    let aspect = 16.0 / 9.0

    init(settings: BrainSettings = BrainSettings()) {
        engine = GestureEngine(settings: settings)
    }

    /// Feeds `duration` seconds of frames; `hands` gets the progress 0...1 through this segment.
    mutating func run(_ duration: Double, _ hands: (Double) -> [SyntheticHand]) {
        let frames = max(Int((duration * fps).rounded()), 1)
        for i in 0..<frames {
            let progress = Double(i + 1) / Double(frames)
            time += 1 / fps
            let frame = HandFrame(timestamp: time, aspect: aspect, hands: hands(progress).map { $0.make() })
            let out = engine.process(frame)
            commands += out.commands
            lastHalo = out.halo
        }
    }

    mutating func hold(_ duration: Double, _ hand: SyntheticHand) {
        run(duration) { _ in [hand] }
    }

    mutating func engage(at center: Vec2 = Vec2(0.9, 0.5)) {
        hold(0.5, .openPalm(at: center))
        commands.removeAll()
    }

    var summary: CommandSummary { CommandSummary(commands) }

    var totalMove: Vec2 {
        commands.reduce(Vec2.zero) { sum, command in
            if case let .move(dx, dy) = command { return sum + Vec2(dx, dy) }
            return sum
        }
    }
}
