import Foundation
import Testing
@testable import AirHaloBrain

// MARK: - Filter and measurements

@Test func oneEuroFilterRemovesJitterFromAStillHand() {
    var filter = OneEuroFilter(minCutoff: 1.0, beta: BrainSettings().filterBeta)
    var generator = SeededRandom(seed: 42)
    var raw: [Double] = []
    var smooth: [Double] = []
    for i in 0..<300 {
        let noisy = 0.5 + generator.next(in: -0.005...0.005)
        raw.append(noisy)
        smooth.append(filter.filter(noisy, at: Double(i) / 30))
    }
    #expect(standardDeviation(smooth.suffix(200)) < standardDeviation(raw.suffix(200)) * 0.5)
}

@Test func oneEuroFilterFollowsFastMovement() {
    var filter = OneEuroFilter(minCutoff: 1.0, beta: BrainSettings().filterBeta)
    var last = 0.0
    for i in 0..<30 { last = filter.filter(Double(i) * 0.03, at: Double(i) / 30) }
    // Moving 0.9 units/s: the filtered value should lag by less than 0.1.
    #expect(abs(last - 29 * 0.03) < 0.1)
}

@Test func poseClassifierRecognisesEachShape() throws {
    let settings = BrainSettings()
    func pose(_ hand: SyntheticHand) throws -> Pose {
        var classifier = PoseClassifier()
        let metrics = try #require(HandMetrics(hand: hand.make()))
        return classifier.classify(metrics, settings: settings)
    }
    #expect(try pose(.openPalm()).openPalm)
    #expect(try pose(.fist()).fist)
    #expect(try pose(.twoFinger()).twoFinger)
    #expect(try pose(.pinching(.index)).indexPinched)
    let middle = try pose(.pinching(.middle))
    #expect(middle.middlePinched && !middle.indexPinched)
    let relaxed = try pose(.relaxed())
    #expect(!relaxed.openPalm && !relaxed.fist && !relaxed.twoFinger && !relaxed.indexPinched)
}

@Test func lowConfidenceHandIsIgnored() {
    var hand = SyntheticHand.openPalm().make()
    hand.points[Joint.wrist.rawValue].confidence = 0.1
    #expect(HandMetrics(hand: hand) == nil)
}

// MARK: - Engaging (no accidental input)

@Test func restingHandNeverMovesThePointer() {
    var session = Session()
    // A relaxed hand drifting around, then a fist: neither may engage.
    session.run(3) { t in [.relaxed(at: Vec2(0.7 + 0.3 * t, 0.5 + 0.1 * sin(t * 12)))] }
    session.run(2) { t in [.fist(at: Vec2(1.0 - 0.2 * t, 0.6))] }
    #expect(session.commands.isEmpty)
    #expect(session.lastHalo.mode == .hidden)
}

@Test func openPalmMustBeHeldToEngage() {
    var session = Session()
    session.hold(0.2, .openPalm())
    #expect(session.lastHalo.mode == .arming)
    #expect(session.lastHalo.armingProgress > 0.5)
    session.hold(0.2, .openPalm())
    #expect(session.lastHalo.mode == .hover)
}

@Test func fistDisengages() {
    var session = Session()
    session.engage()
    session.hold(0.7, .fist())
    #expect(session.lastHalo.mode == .hidden)
    session.run(0.5) { t in [.relaxed(at: Vec2(0.9 + 0.2 * t, 0.5))] }
    #expect(session.commands.isEmpty)
}

// MARK: - Pointer

@Test func movingTheEngagedHandMovesThePointer() {
    var session = Session()
    session.engage()
    session.run(0.5) { t in [.openPalm(at: Vec2(0.9 - 0.1 * t, 0.5))] }  // hand moves left in the mirrored image...
    session.run(1.0) { t in [.relaxed(at: Vec2(0.8 + 0.2 * t, 0.5 + 0.1 * t))] } // ...then right and down
    let moves = session.commands.filter { if case .move = $0 { return true }; return false }
    #expect(!moves.isEmpty)
    #expect(session.totalMove.y > 0)
}

@Test func fastMovementTravelsFurtherThanSlowMovement() {
    let settings = BrainSettings()
    let slow = PointerMapper.relativeDelta(Vec2(0.001, 0), dt: 1.0 / 30, settings: settings)
    let fast = PointerMapper.relativeDelta(Vec2(0.05, 0), dt: 1.0 / 30, settings: settings)
    #expect(fast.x / 0.05 > slow.x / 0.001 * 3)
}

@Test func absoluteModeMapsTheZoneOntoTheScreen() {
    var settings = BrainSettings()
    settings.absoluteZone = ZoneRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    let aspect = 2.0
    let centre = PointerMapper.absolutePosition(Vec2(1.0, 0.5), aspect: aspect, settings: settings)
    #expect(abs(centre.x - 0.5) < 1e-9 && abs(centre.y - 0.5) < 1e-9)
    let corner = PointerMapper.absolutePosition(Vec2(0, 0), aspect: aspect, settings: settings)
    #expect(corner == Vec2(0, 0))
}

// MARK: - Click, drag, right click

@Test func quickPinchIsOneClick() {
    var session = Session()
    session.engage()
    session.hold(0.15, .pinching(.index))
    session.hold(0.2, .openPalm())
    #expect(session.summary.leftClicks == 1)
    #expect(session.summary.drags == 0)
    #expect(session.commands.first == .buttonDown(.left, clickCount: 1))
}

@Test func pointerFreezesWhenAPinchStarts() {
    var session = Session()
    session.engage()
    // The hand drifts slightly as it pinches; the click must not move the pointer.
    session.run(0.1) { t in [SyntheticHand.pinching(.index, at: Vec2(0.9 + 0.003 * t, 0.5))] }
    session.hold(0.1, .openPalm(at: Vec2(0.903, 0.5)))
    let movedWhileDown = session.commands.prefix { $0 != .buttonUp(.left, clickCount: 1) }
        .contains { if case .move = $0 { return true }; return false }
    #expect(!movedWhileDown)
    #expect(session.summary.leftClicks == 1)
}

@Test func twoQuickPinchesAreADoubleClick() {
    var session = Session()
    session.engage()
    session.hold(0.1, .pinching(.index))
    session.hold(0.1, .openPalm())
    session.hold(0.1, .pinching(.index))
    session.hold(0.1, .openPalm())
    let downs = session.commands.compactMap { command -> Int? in
        if case let .buttonDown(.left, count) = command { return count }
        return nil
    }
    #expect(downs == [1, 2])
}

@Test func heldPinchWithMovementIsADrag() {
    var session = Session()
    session.engage()
    session.hold(0.4, .pinching(.index))
    session.run(0.5) { t in [.pinching(.index, at: Vec2(0.9 + 0.15 * t, 0.5))] }
    session.hold(0.2, .openPalm(at: Vec2(1.05, 0.5)))
    #expect(session.summary.drags == 1)
    #expect(session.summary.leftClicks == 0)
}

@Test func thumbToMiddlePinchIsARightClick() {
    var session = Session()
    session.engage()
    session.hold(0.15, .pinching(.middle))
    session.hold(0.2, .openPalm())
    #expect(session.summary.rightClicks == 1)
    #expect(session.summary.leftClicks == 0)
}

@Test func twoHandsInViewNeverClick() {
    var session = Session()
    session.engage()
    session.hold(0.2, .openPalm())
    session.run(0.4) { _ in [.pinching(.index), .openPalm(at: Vec2(0.4, 0.5))] }
    session.hold(0.2, .openPalm())
    #expect(session.summary.leftClicks == 0)
}

// MARK: - Scroll

@Test func twoFingerPoseScrollsWithTheHand() {
    var session = Session()
    session.engage()
    session.hold(0.3, .twoFinger())
    session.run(0.5) { t in [.twoFinger(at: Vec2(0.9, 0.5 + 0.1 * t))] }   // hand moves down
    session.hold(0.2, .openPalm(at: Vec2(0.9, 0.6)))
    let scrolls = session.commands.compactMap { command -> (Double, ScrollPhase)? in
        if case let .scroll(_, dy, phase) = command { return (dy, phase) }
        return nil
    }
    #expect(scrolls.first?.1 == .began)
    #expect(scrolls.contains { $0.1 == .ended })
    let total = scrolls.filter { $0.1 == .began || $0.1 == .changed }.reduce(0) { $0 + $1.0 }
    #expect(total > 0, "natural scrolling: hand down shows content further up")
    #expect(session.summary.scrolls == 1)
}

@Test func fastScrollCoastsAfterLettingGo() {
    var session = Session()
    session.engage()
    session.hold(0.3, .twoFinger())
    session.run(0.2) { t in [.twoFinger(at: Vec2(0.9, 0.5 + 0.2 * t))] }
    session.hold(0.6, .openPalm(at: Vec2(0.9, 0.7)))
    #expect(session.commands.contains { if case .scroll(_, _, .momentum) = $0 { return true }; return false })
    #expect(session.commands.contains(.scroll(dx: 0, dy: 0, phase: .momentumEnded)))
}

// MARK: - Zoom and Spaces

@Test func pullingTwoPinchingHandsApartZoomsIn() {
    var session = Session()
    session.engage(at: Vec2(1.0, 0.5))
    session.run(0.2) { _ in [.openPalm(at: Vec2(1.0, 0.5)), .openPalm(at: Vec2(0.6, 0.5))] }
    session.run(0.6) { t in [.pinching(.index, at: Vec2(1.0 + 0.2 * t, 0.5)), .pinching(.index, at: Vec2(0.6 - 0.2 * t, 0.5))] }
    #expect(session.commands.contains(.zoom(.zoomIn)))
    #expect(!session.commands.contains(.zoom(.zoomOut)))
    #expect(session.summary.leftClicks == 0)
}

@Test func fastFlickSwitchesSpaceAndKeepsThePointerStill() {
    var session = Session()
    session.engage(at: Vec2(1.1, 0.5))
    session.run(0.2) { t in [.openPalm(at: Vec2(1.1 - 0.5 * t, 0.5))] }  // fast flick to the left
    #expect(session.commands.contains(.switchSpace(.right)))
    #expect(abs(session.totalMove.x) < 60)
}

@Test func slowSidewaysMovementDoesNotSwitchSpace() {
    var session = Session()
    session.engage(at: Vec2(1.1, 0.5))
    session.run(2.0) { t in [.openPalm(at: Vec2(1.1 - 0.5 * t, 0.5))] }
    #expect(session.summary.spaceSwitches == 0)
}

// MARK: - Safety

@Test func losingTheHandMidDragReleasesTheButton() {
    var session = Session()
    session.engage()
    session.hold(0.5, .pinching(.index))
    session.run(1.2) { _ in [] }
    #expect(session.commands.last == .buttonUp(.left, clickCount: 1))
    #expect(session.lastHalo.mode == .hidden)
}

@Test func releaseAllLetsGoOfEverything() {
    var session = Session()
    session.engage()
    session.hold(0.5, .pinching(.index))
    #expect(session.engine.releaseAll() == [.buttonUp(.left, clickCount: 1)])
    // After a pause the user has to engage again.
    session.commands.removeAll()
    session.run(0.5) { t in [.relaxed(at: Vec2(0.9 + 0.1 * t, 0.5))] }
    #expect(session.commands.isEmpty)
}

// MARK: - Recorded sessions

@Test func recordedFixturesMatchTheirExpectations() throws {
    let urls = (Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures") ?? [])
    for url in urls {
        let recording = try JSONDecoder().decode(Recording.self, from: Data(contentsOf: url))
        guard let expectation = recording.expect else { continue }
        let engine = GestureEngine()
        let commands = recording.frames.flatMap { engine.process($0).commands }
        let problems = CommandSummary(commands).mismatches(against: expectation)
        #expect(problems.isEmpty, "\(url.lastPathComponent): \(problems.joined(separator: "; "))")
    }
}

// MARK: - Helpers

private func standardDeviation<C: Collection>(_ values: C) -> Double where C.Element == Double {
    guard !values.isEmpty else { return 0 }
    let mean = values.reduce(0, +) / Double(values.count)
    let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
    return variance.squareRoot()
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let unit = Double(state >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
