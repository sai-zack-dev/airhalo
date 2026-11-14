import AirHaloBrain
@preconcurrency import AVFoundation
import QuartzCore

/// What one processed camera frame produced, sent to the main thread.
struct FrameReport: Sendable {
    var frame: HandFrame
    var output: EngineOutput
    var fps: Double
    var latencyMs: Double
}

/// camera → Vision → brain. Everything mutable here is only touched on `queue`.
final class Pipeline: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.airhalo.processing", qos: .userInteractive)
    let camera: CameraService
    private let tracker = VisionHandTracker()
    private let engine = GestureEngine()

    // Queue-confined state
    private var active = false
    private var mirrored = true
    private var recordedFrames: [HandFrame]?
    private var lastHandTime: Double = 0
    private var frameIndex = 0
    private var frameTimes: [Double] = []

    /// Called on the processing queue. Set once, before `start`.
    var onReport: (@Sendable (FrameReport) -> Void)?
    /// Called on the processing queue with commands that aren't tied to a frame (releasing buttons when pausing).
    var onCommands: (@Sendable ([Command]) -> Void)?

    /// After this long with no hand, only every `idleFrameStride`-th frame is analysed, to save power.
    private let idleAfter: Double = 10
    private let idleFrameStride = 3

    init() {
        camera = CameraService(frameQueue: queue)
        camera.onFrame = { [unowned self] buffer in self.process(buffer) }
    }

    func start(deviceID: String?, completion: @escaping @Sendable (Error?) -> Void) {
        camera.start(deviceID: deviceID, completion: completion)
    }

    func stop() {
        camera.stop()
        setActive(false)
    }

    /// Active = the brain may move the pointer. Inactive still tracks (for the Debug window).
    func setActive(_ newValue: Bool) {
        queue.async { [self] in
            guard newValue != active else { return }
            if active {
                let release = engine.releaseAll()
                if !release.isEmpty { onCommands?(release) }
            }
            active = newValue
        }
    }

    func update(settings: BrainSettings, mirrored: Bool) {
        queue.async { [self] in
            engine.settings = settings
            self.mirrored = mirrored
        }
    }

    func startRecording() {
        queue.async { [self] in recordedFrames = [] }
    }

    func stopRecording(completion: @escaping @Sendable (Recording) -> Void) {
        queue.async { [self] in
            let frames = recordedFrames ?? []
            recordedFrames = nil
            completion(Recording(note: "Recorded in AirHalo's Debug window", frames: frames))
        }
    }

    // MARK: - Per frame (on `queue`)

    private func process(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        frameIndex += 1
        let idle = timestamp - lastHandTime > idleAfter
        if idle, frameIndex % idleFrameStride != 0 { return }

        let frame = tracker.track(pixelBuffer, timestamp: timestamp, mirrored: mirrored)
        if !frame.hands.isEmpty { lastHandTime = timestamp }
        recordedFrames?.append(frame)

        let output = active ? engine.process(frame) : EngineOutput()

        frameTimes.append(timestamp)
        frameTimes.removeAll { timestamp - $0 > 1 }
        // Capture timestamps use the host clock, the same clock as CACurrentMediaTime.
        let latency = max(CACurrentMediaTime() - timestamp, 0) * 1000

        onReport?(FrameReport(frame: frame, output: output, fps: Double(frameTimes.count), latencyMs: latency))
    }
}
