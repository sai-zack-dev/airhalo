import AirHaloBrain
import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// Turns brain commands into real macOS input events (needs Accessibility permission).
/// Every event is tagged with `marker` so AirHalo can tell its own events from the real mouse.
@MainActor
final class EventInjector {
    static let marker: Int64 = 0x4149_5248 // "AIRH"

    private let source: CGEventSource?
    private(set) var leftDown = false
    private(set) var rightDown = false
    private var scrollRemainder = CGVector.zero
    private var inMomentum = false

    init() {
        source = CGEventSource(stateID: .hidSystemState)
        // Don't block the real mouse/keyboard for a moment after each posted event.
        source?.localEventsSuppressionInterval = 0
    }

    var canPostEvents: Bool { CGPreflightPostEventAccess() }

    func perform(_ command: Command) {
        switch command {
        case let .move(dx, dy):
            move(by: CGVector(dx: dx, dy: dy))
        case let .moveTo(x, y):
            moveTo(normalized: CGPoint(x: x, y: y))
        case let .buttonDown(button, clickCount):
            press(button, down: true, clickCount: clickCount)
        case let .buttonUp(button, clickCount):
            press(button, down: false, clickCount: clickCount)
        case let .scroll(dx, dy, phase):
            scroll(dx: dx, dy: dy, phase: phase)
        case let .zoom(direction):
            key(direction == .zoomIn ? kVK_ANSI_Equal : kVK_ANSI_Minus, flags: .maskCommand)
        case let .switchSpace(direction):
            key(direction == .right ? kVK_RightArrow : kVK_LeftArrow,
                flags: [.maskControl, .maskSecondaryFn, .maskNumericPad])
        }
    }

    /// Lets go of any held button (used when quitting or disabling).
    func releaseButtons() {
        if leftDown { press(.left, down: false, clickCount: 1) }
        if rightDown { press(.right, down: false, clickCount: 1) }
    }

    // MARK: - Pointer

    func move(by delta: CGVector) {
        guard delta.dx != 0 || delta.dy != 0 else { return }
        let current = currentLocation()
        let target = clampToDisplays(CGPoint(x: current.x + delta.dx, y: current.y + delta.dy), from: current)
        postMove(to: target, delta: CGVector(dx: target.x - current.x, dy: target.y - current.y))
    }

    func moveTo(normalized p: CGPoint) {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let target = CGPoint(x: bounds.minX + p.x * (bounds.width - 1), y: bounds.minY + p.y * (bounds.height - 1))
        let current = currentLocation()
        postMove(to: target, delta: CGVector(dx: target.x - current.x, dy: target.y - current.y))
    }

    private func postMove(to point: CGPoint, delta: CGVector) {
        let type: CGEventType
        let button: CGMouseButton
        if leftDown {
            (type, button) = (.leftMouseDragged, .left)
        } else if rightDown {
            (type, button) = (.rightMouseDragged, .right)
        } else {
            (type, button) = (.mouseMoved, .left)
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(delta.dx.rounded()))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(delta.dy.rounded()))
        post(event)
    }

    private func press(_ button: MouseButton, down: Bool, clickCount: Int) {
        let type: CGEventType
        let cgButton: CGMouseButton
        switch (button, down) {
        case (.left, true): (type, cgButton) = (.leftMouseDown, .left)
        case (.left, false): (type, cgButton) = (.leftMouseUp, .left)
        case (.right, true): (type, cgButton) = (.rightMouseDown, .right)
        case (.right, false): (type, cgButton) = (.rightMouseUp, .right)
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: currentLocation(), mouseButton: cgButton) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: Int64(max(clickCount, 1)))
        post(event)
        if button == .left { leftDown = down } else { rightDown = down }
    }

    // MARK: - Scroll

    private func scroll(dx: Double, dy: Double, phase: ScrollPhase) {
        // Pixel scroll events take whole numbers; carry the fractions over.
        let x = dx + scrollRemainder.dx
        let y = dy + scrollRemainder.dy
        let wheelX = Int32(x.rounded(.towardZero))
        let wheelY = Int32(y.rounded(.towardZero))
        scrollRemainder = CGVector(dx: x - Double(wheelX), dy: y - Double(wheelY))

        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                                  wheel1: wheelY, wheel2: wheelX, wheel3: 0) else { return }
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

        // Phase fields, as a trackpad sends them (kCGScrollWheelEventScrollPhase / MomentumPhase).
        let scrollPhaseField = CGEventField(rawValue: 99)!
        let momentumPhaseField = CGEventField(rawValue: 123)!
        switch phase {
        case .began:
            inMomentum = false
            event.setIntegerValueField(scrollPhaseField, value: 1)      // kCGScrollPhaseBegan
        case .changed:
            event.setIntegerValueField(scrollPhaseField, value: 2)      // kCGScrollPhaseChanged
        case .ended:
            event.setIntegerValueField(scrollPhaseField, value: 4)      // kCGScrollPhaseEnded
            scrollRemainder = .zero
        case .momentum:
            event.setIntegerValueField(momentumPhaseField, value: inMomentum ? 2 : 1) // continue : begin
            inMomentum = true
        case .momentumEnded:
            event.setIntegerValueField(momentumPhaseField, value: 3)    // end
            inMomentum = false
            scrollRemainder = .zero
        }
        post(event)
    }

    // MARK: - Keys

    private func key(_ keyCode: Int, flags: CGEventFlags) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: down) else { continue }
            event.flags = flags
            post(event)
        }
    }

    // MARK: - Helpers

    private func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.post(tap: .cghidEventTap)
    }

    /// Pointer position in global display coordinates (origin top-left of the main display).
    private func currentLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// Keeps the pointer on a screen: if the target is off every display, clamp it to the display it came from.
    private func clampToDisplays(_ point: CGPoint, from origin: CGPoint) -> CGPoint {
        let displays = activeDisplayBounds()
        if displays.contains(where: { $0.contains(point) }) { return point }
        let home = displays.first(where: { $0.contains(origin) }) ?? displays.first ?? CGDisplayBounds(CGMainDisplayID())
        return CGPoint(x: min(max(point.x, home.minX), home.maxX - 1),
                       y: min(max(point.y, home.minY), home.maxY - 1))
    }

    private func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }
}
