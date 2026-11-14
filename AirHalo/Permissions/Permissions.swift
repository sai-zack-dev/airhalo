import AppKit
@preconcurrency import AVFoundation
import ApplicationServices

/// Camera and Accessibility permission checks.
enum Permissions {
    static var cameraStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static var cameraGranted: Bool { cameraStatus == .authorized }

    static func requestCamera() async -> Bool {
        switch cameraStatus {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// Needed to move the pointer and click (posting events to other apps).
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that offers to open Accessibility settings.
    static func promptForAccessibility() {
        // The key's value is "AXTrustedCheckOptionPrompt"; the global constant isn't concurrency-safe in Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openCameraSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
    }

    static func openKeyboardShortcutsSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    /// Whether "Move left/right a space" (⌃← / ⌃→) are turned on in Keyboard Shortcuts.
    /// AirHalo's Space swipe sends those shortcuts.
    static var spaceShortcutsEnabled: Bool {
        guard let hotkeys = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString,
                                                      "com.apple.symbolichotkeys" as CFString) as? [String: Any]
        else { return true }  // never customised → defaults, which are on
        func enabled(_ id: String) -> Bool {
            guard let entry = hotkeys[id] as? [String: Any] else { return true }
            return (entry["enabled"] as? Bool) ?? true
        }
        return enabled("79") && enabled("81")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
