import AppKit
import SwiftUI

/// Opens AirHalo's windows. It's a menu bar app (no Dock icon), so each window
/// brings the app forward when it opens.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    private unowned let delegate: AppDelegate
    private var onboarding: NSWindow?
    private var settings: NSWindow?
    private var debug: NSWindow?

    init(delegate: AppDelegate) {
        self.delegate = delegate
    }

    func showOnboarding() {
        let window = onboarding ?? makeWindow(
            title: "Welcome to AirHalo",
            size: NSSize(width: 520, height: 560),
            content: OnboardingView(model: delegate.model, delegate: delegate)
        )
        onboarding = window
        present(window)
    }

    func closeOnboarding() {
        onboarding?.close()
    }

    func showSettings() {
        let window = settings ?? makeWindow(
            title: "AirHalo Settings",
            size: NSSize(width: 480, height: 640),
            content: SettingsView(model: delegate.model)
        )
        settings = window
        present(window)
    }

    func showDebug() {
        let window = debug ?? makeWindow(
            title: "AirHalo Debug",
            size: NSSize(width: 760, height: 620),
            content: DebugView(model: delegate.model, delegate: delegate, session: delegate.pipeline.camera.session)
        )
        debug = window
        present(window)
        delegate.debugWindowOpened()
    }

    private func makeWindow<Content: View>(title: String, size: NSSize, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = NSHostingController(rootView: content)
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    private func present(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === debug {
            delegate.debugWindowClosed()
        }
    }
}
