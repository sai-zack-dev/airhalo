import Foundation

/// The gesture state machine: hand frames in, pointer commands and halo state out.
///
/// Not thread-safe: feed it from one queue. Platform-independent: all it needs is
/// `HandFrame`s in the coordinate convention documented there.
public final class GestureEngine {
    public var settings: BrainSettings {
        didSet { filter.configure(minCutoff: settings.filterMinCutoff, beta: settings.filterBeta) }
    }

    enum Mode: Equatable {
        case idle
        case hover
        case pressing        // left button down, not yet a drag
        case dragging
        case rightPressing
        case scrolling
        case zooming
    }

    private(set) var mode: Mode = .idle

    private var filter: OneEuroFilter2D
    private var primaryClassifier = PoseClassifier()
    private var secondaryClassifier = PoseClassifier()

    // Hand identity
    private var lastPrimaryPalm: Vec2?
    private var lastHandSeen: Double?

    // Movement
    private var lastFilteredPalm: Vec2?
    private var lastTime: Double?
    private var freezeUntil: Double = 0

    // Engage / disengage timers
    private var openPalmSince: Double?
    private var fistSince: Double?
    private var twoFingerSince: Double?

    // Click / drag
    private var pressStartTime: Double = 0
    private var pressStartPalm: Vec2 = .zero
    private var pressClickCount = 1
    private var lastClickDownTime: Double?
    private var lastClickCount = 0
    private var travelSinceClick: Double = 0

    // Scroll
    private var scrollStarted = false
    private var scrollVelocity: Vec2 = .zero
    private var momentumUntil: Double?
    private var momentumTime: Double = 0

    // Zoom
    private var zoomAnchor: Double?

    // Swipe
    private struct SwipeSample { var time: Double; var palm: Vec2; var scale: Double }
    private var swipeSamples: [SwipeSample] = []
    private var lastSwipe: Double = -.infinity
    private var recentMoves: [(time: Double, delta: Vec2)] = []

    public init(settings: BrainSettings = BrainSettings()) {
        self.settings = settings
        filter = OneEuroFilter2D(minCutoff: settings.filterMinCutoff, beta: settings.filterBeta)
    }

    // MARK: - Public

    /// Releases any held buttons, ends scrolling and returns to idle (the user must
    /// show an open palm again). Call when pausing.
    public func releaseAll() -> [Command] {
        var commands = endActiveGesture()
        if momentumUntil != nil {
            commands.append(.scroll(dx: 0, dy: 0, phase: .momentumEnded))
            momentumUntil = nil
        }
        mode = .idle
        resetTracking()
        return commands
    }

    public func process(_ frame: HandFrame) -> EngineOutput {
        let t = frame.timestamp
        var commands: [Command] = []
        commands += continueMomentum(at: t)

        let candidates = frame.hands.compactMap { hand -> (Hand, HandMetrics)? in
            guard let m = HandMetrics(hand: hand, minConfidence: settings.minJointConfidence) else { return nil }
            return (hand, m)
        }

        guard let primaryIndex = pickPrimary(candidates.map(\.1)) else {
            return EngineOutput(commands: commands + handLost(at: t), halo: haloForMissingHand())
        }

        let metrics = candidates[primaryIndex].1
        let secondary = candidates.indices.first { $0 != primaryIndex }.map { candidates[$0].1 }
        lastHandSeen = t
        lastPrimaryPalm = metrics.palmCenter

        let pose = primaryClassifier.classify(metrics, settings: settings)
        let secondaryPose = secondary.map { secondaryClassifier.classify($0, settings: settings) }
        if secondary == nil { secondaryClassifier.reset() }

        let filtered = filter.filter(metrics.palmCenter, at: t)
        let delta = lastFilteredPalm.map { filtered - $0 } ?? .zero
        let dt = lastTime.map { t - $0 } ?? 0
        defer {
            lastFilteredPalm = filtered
            lastTime = t
        }

        if mode == .idle {
            return EngineOutput(commands: commands, halo: updateIdle(pose: pose, at: t))
        }

        // Fist held → stop.
        if pose.fist {
            fistSince = fistSince ?? t
            if t - fistSince! >= settings.fistDisengageHold {
                commands += disengage()
                return EngineOutput(commands: commands, halo: .hidden)
            }
        } else {
            fistSince = nil
        }

        let twoHands = secondary != nil

        switch mode {
        case .idle:
            break

        case .hover:
            if settings.zoomEnabled, twoHands, pose.indexPinched, secondaryPose?.indexPinched == true, let secondary {
                mode = .zooming
                zoomAnchor = metrics.pinchPoint.distance(to: secondary.pinchPoint)
            } else if pose.indexPinched, !twoHands {
                pressClickCount = clickCount(at: t)
                commands.append(.buttonDown(.left, clickCount: pressClickCount))
                mode = .pressing
                pressStartTime = t
                pressStartPalm = filtered
                freezeUntil = t + settings.clickFreeze
            } else if pose.middlePinched, !twoHands {
                commands.append(.buttonDown(.right, clickCount: 1))
                mode = .rightPressing
                freezeUntil = t + settings.clickFreeze
            } else if settings.scrollEnabled, pose.twoFinger {
                twoFingerSince = twoFingerSince ?? t
                if t - twoFingerSince! >= settings.scrollHold {
                    mode = .scrolling
                    scrollStarted = false
                    scrollVelocity = .zero
                    momentumUntil = nil
                }
            } else {
                twoFingerSince = nil
            }

            if mode == .hover {
                if let swipe = detectSwipe(pose: pose, metrics: metrics, at: t) {
                    commands += swipe
                } else {
                    commands += movePointer(delta: delta, dt: dt, palm: filtered, aspect: frame.aspect, at: t)
                }
            }

        case .pressing:
            if !pose.indexPinched {
                commands.append(.buttonUp(.left, clickCount: pressClickCount))
                registerClick(at: pressStartTime)
                mode = .hover
            } else if t - pressStartTime >= settings.dragHoldTime
                        || filtered.distance(to: pressStartPalm) > settings.dragDeadzone {
                mode = .dragging
            }

        case .dragging:
            if !pose.indexPinched {
                commands.append(.buttonUp(.left, clickCount: pressClickCount))
                mode = .hover
            } else {
                commands += movePointer(delta: delta, dt: dt, palm: filtered, aspect: frame.aspect, at: t)
            }

        case .rightPressing:
            if !pose.middlePinched {
                commands.append(.buttonUp(.right, clickCount: 1))
                mode = .hover
            }

        case .scrolling:
            // Keep scrolling while index and middle are up and ring and little aren't
            // fully straight. Small wobbles shouldn't end it; opening the hand should.
            let stillScrolling = metrics.isExtended(.index, settings: settings)
                && metrics.isExtended(.middle, settings: settings)
                && !metrics.isExtended(.ring, settings: settings)
                && !metrics.isExtended(.little, settings: settings)
                && !pose.indexPinched
            if stillScrolling {
                commands.append(scroll(delta: delta, dt: dt))
            } else {
                commands += endScroll(at: t)
                mode = .hover
            }

        case .zooming:
            guard let secondary, pose.indexPinched, secondaryPose?.indexPinched == true, let anchor = zoomAnchor else {
                mode = .hover
                zoomAnchor = nil
                break
            }
            let distance = metrics.pinchPoint.distance(to: secondary.pinchPoint)
            if distance > anchor * (1 + settings.zoomStep) {
                commands.append(.zoom(.zoomIn))
                zoomAnchor = distance
            } else if distance < anchor * (1 - settings.zoomStep) {
                commands.append(.zoom(.zoomOut))
                zoomAnchor = distance
            }
        }

        return EngineOutput(commands: commands, halo: halo(metrics: metrics))
    }

    // MARK: - Hands

    /// Keeps following the same hand: the one nearest to where the primary hand was,
    /// or the biggest (closest to the camera) when starting fresh.
    private func pickPrimary(_ metrics: [HandMetrics]) -> Int? {
        guard !metrics.isEmpty else { return nil }
        if let last = lastPrimaryPalm, mode != .idle {
            return metrics.indices.min { metrics[$0].palmCenter.distance(to: last) < metrics[$1].palmCenter.distance(to: last) }
        }
        return metrics.indices.max { metrics[$0].scale < metrics[$1].scale }
    }

    private func handLost(at t: Double) -> [Command] {
        openPalmSince = nil
        fistSince = nil
        twoFingerSince = nil
        guard mode != .idle else { return [] }
        if let seen = lastHandSeen, t - seen >= settings.lostHandTimeout {
            return disengage()
        }
        return []
    }

    private func haloForMissingHand() -> HaloState {
        switch mode {
        case .idle: return .hidden
        default: return HaloState(mode: .hover)
        }
    }

    // MARK: - Engage

    private func updateIdle(pose: Pose, at t: Double) -> HaloState {
        guard pose.openPalm else {
            openPalmSince = nil
            return .hidden
        }
        openPalmSince = openPalmSince ?? t
        let progress = settings.engageHold > 0 ? (t - openPalmSince!) / settings.engageHold : 1
        if progress >= 1 {
            mode = .hover
            openPalmSince = nil
            freezeUntil = t
            swipeSamples.removeAll()
            return HaloState(mode: .hover)
        }
        return HaloState(mode: .arming, armingProgress: progress)
    }

    private func disengage() -> [Command] {
        let commands = endActiveGesture()
        mode = .idle
        openPalmSince = nil
        fistSince = nil
        twoFingerSince = nil
        lastPrimaryPalm = nil
        primaryClassifier.reset()
        secondaryClassifier.reset()
        swipeSamples.removeAll()
        return commands
    }

    private func endActiveGesture() -> [Command] {
        switch mode {
        case .pressing, .dragging:
            return [.buttonUp(.left, clickCount: pressClickCount)]
        case .rightPressing:
            return [.buttonUp(.right, clickCount: 1)]
        case .scrolling:
            return scrollStarted ? [.scroll(dx: 0, dy: 0, phase: .ended)] : []
        case .idle, .hover, .zooming:
            return []
        }
    }

    private func resetTracking() {
        filter.reset()
        primaryClassifier.reset()
        secondaryClassifier.reset()
        lastFilteredPalm = nil
        lastTime = nil
        lastPrimaryPalm = nil
        lastHandSeen = nil
        openPalmSince = nil
        fistSince = nil
        twoFingerSince = nil
        zoomAnchor = nil
        swipeSamples.removeAll()
        recentMoves.removeAll()
    }

    // MARK: - Pointer

    private func movePointer(delta: Vec2, dt: Double, palm: Vec2, aspect: Double, at t: Double) -> [Command] {
        guard t >= freezeUntil else { return [] }
        switch settings.pointerMode {
        case .relative:
            guard dt > 0, delta != .zero else { return [] }
            let move = PointerMapper.relativeDelta(delta, dt: dt, settings: settings)
            travelSinceClick += move.length
            recentMoves.append((t, move))
            recentMoves.removeAll { t - $0.time > settings.swipeWindow }
            return [.move(dx: move.x, dy: move.y)]
        case .absolute:
            let p = PointerMapper.absolutePosition(palm, aspect: aspect, settings: settings)
            travelSinceClick += delta.length * settings.minGain
            return [.moveTo(x: p.x, y: p.y)]
        }
    }

    private func clickCount(at t: Double) -> Int {
        if let last = lastClickDownTime,
           t - last <= settings.doubleClickInterval,
           travelSinceClick <= settings.doubleClickRadius {
            return min(lastClickCount + 1, 3)
        }
        return 1
    }

    private func registerClick(at downTime: Double) {
        lastClickDownTime = downTime
        lastClickCount = pressClickCount
        travelSinceClick = 0
    }

    // MARK: - Scroll

    private func scroll(delta: Vec2, dt: Double) -> Command {
        let sign = settings.naturalScroll ? 1.0 : -1.0
        let amount = delta * (settings.scrollGain * settings.sensitivity * sign)
        if dt > 0 {
            let velocity = amount / dt
            scrollVelocity = scrollVelocity * 0.6 + velocity * 0.4
        }
        let phase: ScrollPhase = scrollStarted ? .changed : .began
        scrollStarted = true
        return .scroll(dx: amount.x, dy: amount.y, phase: phase)
    }

    private func endScroll(at t: Double) -> [Command] {
        guard scrollStarted else { return [] }
        scrollStarted = false
        if settings.scrollMomentum > 0, scrollVelocity.length > 200 {
            momentumUntil = t + settings.scrollMomentum
            momentumTime = t
        } else {
            scrollVelocity = .zero
        }
        return [.scroll(dx: 0, dy: 0, phase: .ended)]
    }

    private func continueMomentum(at t: Double) -> [Command] {
        guard let until = momentumUntil else { return [] }
        let dt = t - momentumTime
        momentumTime = t
        guard t < until, dt > 0 else {
            momentumUntil = nil
            scrollVelocity = .zero
            return [.scroll(dx: 0, dy: 0, phase: .momentumEnded)]
        }
        let tau = max(settings.scrollMomentum / 3, 0.01)
        scrollVelocity = scrollVelocity * exp(-dt / tau)
        let step = scrollVelocity * dt
        return [.scroll(dx: step.x, dy: step.y, phase: .momentum)]
    }

    // MARK: - Swipe between Spaces

    /// A fast sideways flick with an open palm. Moving the hand left goes to the
    /// Space on the right, like swiping a trackpad.
    private func detectSwipe(pose: Pose, metrics: HandMetrics, at t: Double) -> [Command]? {
        guard settings.swipeEnabled, pose.openPalm else {
            swipeSamples.removeAll()
            return nil
        }
        swipeSamples.append(SwipeSample(time: t, palm: metrics.palmCenter, scale: metrics.scale))
        swipeSamples.removeAll { t - $0.time > settings.swipeWindow }

        guard t - lastSwipe >= settings.swipeCooldown,
              let first = swipeSamples.first, swipeSamples.count >= 3 else { return nil }
        let travel = metrics.palmCenter - first.palm
        let scale = (first.scale + metrics.scale) / 2
        let elapsed = max(t - first.time, 1e-3)
        let travelScales = abs(travel.x) / scale
        guard travelScales >= settings.swipeMinTravel,
              travelScales / elapsed >= settings.swipeMinSpeed,
              abs(travel.x) > 2 * abs(travel.y) else { return nil }

        lastSwipe = t
        swipeSamples.removeAll()
        // The hand is still finishing the flick: keep the pointer still meanwhile.
        freezeUntil = t + settings.swipeWindow + 0.1
        // Undo the pointer movement the flick caused, so the pointer stays put.
        let undo = recentMoves.reduce(Vec2.zero) { $0 + $1.delta } * -1
        recentMoves.removeAll()
        var commands: [Command] = []
        if undo != .zero, settings.pointerMode == .relative {
            commands.append(.move(dx: undo.x, dy: undo.y))
        }
        commands.append(.switchSpace(travel.x < 0 ? .right : .left))
        return commands
    }

    // MARK: - Halo

    private func halo(metrics: HandMetrics) -> HaloState {
        let openAt = settings.pinchOpen * 1.6
        let progress = min(max((openAt - metrics.indexPinch) / (openAt - settings.pinchClose), 0), 1)
        let haloMode: HaloState.Mode
        switch mode {
        case .idle: return .hidden
        case .hover: haloMode = .hover
        case .pressing: haloMode = .pressed
        case .dragging: haloMode = .dragging
        case .rightPressing: haloMode = .rightPressed
        case .scrolling: haloMode = .scrolling
        case .zooming: haloMode = .zooming
        }
        return HaloState(mode: haloMode, pinchProgress: progress)
    }
}
