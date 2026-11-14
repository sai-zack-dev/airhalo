import AirHaloBrain
import AppKit
import QuartzCore

/// Runs brain commands on the main thread.
///
/// The camera delivers 30–60 frames a second, but displays refresh at 60–120 Hz. With
/// smoothing on, each pointer move is spread across the display frames until the next
/// camera frame arrives, so the pointer glides instead of stepping. Other commands
/// first flush any pending movement, so clicks always land where the pointer is.
@MainActor
final class CommandExecutor: NSObject {
    let injector: EventInjector
    var smoothPointer = true

    private var pending = CGVector.zero
    private var rate = CGVector.zero          // points per second
    private var lastArrival: CFTimeInterval = 0
    private var frameInterval: CFTimeInterval = 1.0 / 30
    private var lastTick: CFTimeInterval = 0
    private var displayLink: CADisplayLink?

    init(injector: EventInjector) {
        self.injector = injector
        super.init()
    }

    func execute(_ commands: [Command]) {
        for command in commands {
            if case let .move(dx, dy) = command, smoothPointer {
                queueMove(CGVector(dx: dx, dy: dy))
            } else {
                flush()
                injector.perform(command)
            }
        }
    }

    /// Posts any movement still waiting.
    func flush() {
        if pending.dx != 0 || pending.dy != 0 { injector.move(by: pending) }
        pending = .zero
        rate = .zero
    }

    private func queueMove(_ delta: CGVector) {
        let now = CACurrentMediaTime()
        if lastArrival > 0 {
            let gap = now - lastArrival
            if gap > 0.004, gap < 0.2 { frameInterval = frameInterval * 0.8 + gap * 0.2 }
        }
        lastArrival = now
        pending.dx += delta.dx
        pending.dy += delta.dy
        let interval = min(max(frameInterval, 1.0 / 240), 0.1)
        rate = CGVector(dx: pending.dx / interval, dy: pending.dy / interval)
        startDisplayLinkIfNeeded()
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil, let screen = NSScreen.main else { return }
        let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTick = CACurrentMediaTime()
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.05)
        lastTick = now

        guard pending.dx != 0 || pending.dy != 0 else {
            // Nothing to do for a while: stop ticking to save power.
            if now - lastArrival > 0.5 {
                displayLink?.invalidate()
                displayLink = nil
            }
            return
        }
        var step = CGVector(dx: rate.dx * dt, dy: rate.dy * dt)
        if abs(step.dx) > abs(pending.dx) { step.dx = pending.dx }
        if abs(step.dy) > abs(pending.dy) { step.dy = pending.dy }
        pending.dx -= step.dx
        pending.dy -= step.dy
        injector.move(by: step)
    }
}
