import AppKit

/// Notices when you use the real mouse, trackpad or keyboard, so AirHalo can step aside.
/// Events AirHalo posts itself carry `EventInjector.marker` and are ignored.
@MainActor
final class RealInputMonitor {
    var onRealInput: (() -> Void)?
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown,
        ]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let ours = event.cgEvent?.getIntegerValueField(.eventSourceUserData) == EventInjector.marker
            guard !ours else { return }
            MainActor.assumeIsolated { self?.onRealInput?() }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
