import AirHaloBrain
import Foundation
import Observation

/// Everything the user can change, saved between launches.
struct AppSettings: Codable, Equatable {
    var enabled = true
    var brain = BrainSettings()
    var cameraID: String?
    /// Mirror the camera like a selfie (on for front-facing cameras).
    var mirror = true
    /// Spread pointer movement across display frames.
    var smoothPointer = true
    var pauseOnRealInput = true
    var pauseForVideoCalls = true
    var videoCallApps = [
        "us.zoom.xos",
        "com.apple.FaceTime",
        "com.microsoft.teams2",
        "com.microsoft.teams",
        "com.cisco.webexmeetingsapp",
        "Cisco-Systems.Spark",
    ]

    static let storageKey = "AirHalo.settings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

enum PauseReason: Equatable {
    case realInput
    case videoCall(appName: String)
    case screenLocked
    case sleeping

    var description: String {
        switch self {
        case .realInput: "Paused while you use the mouse or keyboard"
        case let .videoCall(name): "Paused during \(name)"
        case .screenLocked: "Paused while the screen is locked"
        case .sleeping: "Paused while the Mac sleeps"
        }
    }
}

/// App state shown in the UI. Main thread only.
@MainActor
@Observable
final class AppModel {
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            onSettingsChanged?(oldValue)
        }
    }

    // Permissions
    var cameraGranted = Permissions.cameraGranted
    var accessibilityGranted = Permissions.accessibilityGranted
    var permissionsOK: Bool { cameraGranted && accessibilityGranted }

    // Status
    var cameraRunning = false
    var cameraError: String?
    var pauseReason: PauseReason?
    var halo = HaloState.hidden
    var cameras: [CameraInfo] = []

    // Debug window
    var debugWindowOpen = false
    var lastFrame: HandFrame?
    var fps: Double = 0
    var latencyMs: Double = 0
    var isRecording = false
    var lastRecordingURL: URL?

    @ObservationIgnored var onSettingsChanged: ((AppSettings) -> Void)?

    init() {
        settings = AppSettings.load()
    }

    func refreshPermissions() {
        cameraGranted = Permissions.cameraGranted
        accessibilityGranted = Permissions.accessibilityGranted
    }

    var isActive: Bool {
        settings.enabled && permissionsOK && cameraRunning && pauseReason == nil
    }

    var statusText: String {
        if !permissionsOK { return "Needs permissions" }
        if let cameraError { return cameraError }
        if !settings.enabled { return "Off" }
        if let pauseReason { return pauseReason.description }
        if !cameraRunning { return "Starting camera…" }
        switch halo.mode {
        case .hidden: return "Show an open palm to start"
        case .arming: return "Hold your palm…"
        default: return "Tracking your hand"
        }
    }

    var menuBarSymbol: String {
        if !settings.enabled || !permissionsOK { return "hand.raised.slash" }
        if pauseReason != nil { return "pause.circle" }
        return halo.mode == .hidden || halo.mode == .arming ? "hand.raised" : "hand.raised.fill"
    }
}
