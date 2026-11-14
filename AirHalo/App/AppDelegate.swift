import AirHaloBrain
import AppKit

/// Wires the pieces together: camera pipeline → command executor → events, plus the
/// halo, auto-pause, the hotkey and windows.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let pipeline = Pipeline()
    private let injector = EventInjector()
    private lazy var executor = CommandExecutor(injector: injector)
    private let overlay = HaloOverlay()
    private let realInput = RealInputMonitor()
    private var hotkey: Hotkey?
    private(set) lazy var windows = WindowManager(delegate: self)

    private var realInputResume: DispatchWorkItem?
    private var permissionPoll: Timer?
    private var screenLocked = false
    private var sleeping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        pipeline.onReport = { [weak self] report in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.handle(report) } }
        }
        pipeline.onCommands = { [weak self] commands in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.executor.execute(commands) } }
        }
        model.onSettingsChanged = { [weak self] old in self?.settingsChanged(from: old) }
        model.cameras = CameraService.availableCameras()
        applySettingsToPipeline()

        hotkey = Hotkey { [weak self] in self?.toggleEnabled() }
        realInput.onRealInput = { [weak self] in self?.realInputDetected() }
        realInput.start()
        observeSystem()

        model.refreshPermissions()
        if model.permissionsOK {
            startCameraIfNeeded()
        } else {
            windows.showOnboarding()
            startPermissionPolling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        executor.flush()
        injector.releaseButtons()
        pipeline.stop()
    }

    // MARK: - Enable / disable

    func toggleEnabled() {
        model.settings.enabled.toggle()
    }

    private func settingsChanged(from old: AppSettings) {
        let new = model.settings
        applySettingsToPipeline()
        if new.enabled != old.enabled || new.cameraID != old.cameraID {
            if new.enabled {
                startCameraIfNeeded(restart: new.cameraID != old.cameraID)
            } else if !model.debugWindowOpen {
                stopCamera()
            }
        }
        if !new.pauseForVideoCalls, case .videoCall = model.pauseReason { model.pauseReason = nil }
        updateActive()
    }

    private func applySettingsToPipeline() {
        var brain = model.settings.brain
        brain.doubleClickInterval = NSEvent.doubleClickInterval
        pipeline.update(settings: brain, mirrored: model.settings.mirror)
        executor.smoothPointer = model.settings.smoothPointer
    }

    // MARK: - Camera

    /// Starts the camera when AirHalo is on (or the Debug window needs it).
    func startCameraIfNeeded(restart: Bool = false) {
        guard model.cameraGranted, model.settings.enabled || model.debugWindowOpen else { return }
        guard restart || !model.cameraRunning else { updateActive(); return }
        model.cameraError = nil
        pipeline.start(deviceID: model.settings.cameraID) { [weak self] error in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.model.cameraRunning = error == nil
                    self.model.cameraError = error?.localizedDescription
                    self.updateActive()
                }
            }
        }
    }

    func stopCamera() {
        pipeline.stop()
        model.cameraRunning = false
        updateActive()
    }

    /// Whether the brain may move the pointer right now.
    private func updateActive() {
        let active = model.isActive && !sleeping && !screenLocked
        pipeline.setActive(active)
        if !active {
            executor.flush()
            overlay.hide()
            model.halo = .hidden
        }
    }

    // MARK: - Frames

    private func handle(_ report: FrameReport) {
        executor.execute(report.output.commands)
        if model.isActive {
            overlay.update(report.output.halo)
            if model.halo != report.output.halo { model.halo = report.output.halo }
        }
        if model.debugWindowOpen {
            model.lastFrame = report.frame
            model.fps = report.fps
            model.latencyMs = report.latencyMs
        }
    }

    // MARK: - Auto-pause

    private func realInputDetected() {
        guard model.settings.pauseOnRealInput, model.settings.enabled else { return }
        if model.pauseReason == nil {
            model.pauseReason = .realInput
            updateActive()
        }
        realInputResume?.cancel()
        let resume = DispatchWorkItem { [weak self] in
            guard let self, self.model.pauseReason == .realInput else { return }
            self.model.pauseReason = nil
            self.updateActive()
        }
        realInputResume = resume
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: resume)
    }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            let name = app?.localizedName ?? "a call"
            MainActor.assumeIsolated { self?.frontAppChanged(bundleID: bundleID, name: name) }
        }
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setSleeping(true) }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setSleeping(false) }
        }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(true) }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(false) }
        }
    }

    private func frontAppChanged(bundleID: String?, name: String) {
        let isCall = model.settings.pauseForVideoCalls && bundleID.map(model.settings.videoCallApps.contains) == true
        if isCall {
            model.pauseReason = .videoCall(appName: name)
        } else if case .videoCall = model.pauseReason {
            model.pauseReason = nil
        }
        updateActive()
    }

    private func setSleeping(_ value: Bool) {
        sleeping = value
        if value {
            pipeline.stop()
            model.cameraRunning = false
        } else {
            startCameraIfNeeded()
        }
        updateActive()
    }

    private func setLocked(_ value: Bool) {
        screenLocked = value
        if value {
            pipeline.stop()
            model.cameraRunning = false
        } else {
            startCameraIfNeeded()
        }
        updateActive()
    }

    // MARK: - Permissions

    func startPermissionPolling() {
        permissionPoll?.invalidate()
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let wasOK = self.model.permissionsOK
                self.model.refreshPermissions()
                if self.model.permissionsOK {
                    self.permissionPoll?.invalidate()
                    self.permissionPoll = nil
                    if !wasOK { self.startCameraIfNeeded() }
                }
            }
        }
    }

    // MARK: - Debug window

    func debugWindowOpened() {
        model.debugWindowOpen = true
        startCameraIfNeeded()
    }

    func debugWindowClosed() {
        model.debugWindowOpen = false
        if model.isRecording { stopRecording() }
        if !model.settings.enabled { stopCamera() }
    }

    func startRecording() {
        model.isRecording = true
        pipeline.startRecording()
    }

    func stopRecording() {
        model.isRecording = false
        pipeline.stopRecording { recording in
            let url = Self.saveRecording(recording)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { [weak self] in self?.model.lastRecordingURL = url }
            }
        }
    }

    nonisolated private static func saveRecording(_ recording: Recording) -> URL? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = support.appendingPathComponent("AirHalo/Recordings", isDirectory: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = folder.appendingPathComponent("recording_\(formatter.string(from: Date())).json")
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(recording).write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
