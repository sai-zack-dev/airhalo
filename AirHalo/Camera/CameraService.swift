@preconcurrency import AVFoundation
import CoreMedia

struct CameraInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

enum CameraError: LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noCamera: "No camera found."
        case .cannotAddInput: "The camera couldn't be opened. Another app may be using it exclusively."
        case .cannotAddOutput: "The camera's video output couldn't be set up."
        }
    }
}

/// Owns the AVCaptureSession. Frames are delivered on `frameQueue`.
final class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Where `onFrame` is called.
    let frameQueue: DispatchQueue
    /// Session setup, start and stop (these block, so they stay off the main thread).
    private let sessionQueue = DispatchQueue(label: "app.airhalo.camera-session")
    private let output = AVCaptureVideoDataOutput()

    /// Called on `frameQueue` for every frame. Set before `start`.
    var onFrame: ((CMSampleBuffer) -> Void)?

    init(frameQueue: DispatchQueue) {
        self.frameQueue = frameQueue
        super.init()
    }

    static func availableCameras() -> [CameraInfo] {
        discovery().devices.map { CameraInfo(id: $0.uniqueID, name: $0.localizedName) }
    }

    private static func discovery() -> AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
    }

    /// Configures (or reconfigures) the session for a camera and starts it.
    func start(deviceID: String?, completion: @escaping @Sendable (Error?) -> Void) {
        sessionQueue.async { [self] in
            do {
                let device = try configure(deviceID: deviceID)
                // After the session is configured, so the session preset doesn't override it.
                Self.selectFastFormat(for: device)
                if !session.isRunning { session.startRunning() }
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure(deviceID: String?) throws -> AVCaptureDevice {
        let devices = Self.discovery().devices
        guard let device = devices.first(where: { $0.uniqueID == deviceID })
                ?? AVCaptureDevice.default(for: .video)
                ?? devices.first
        else { throw CameraError.noCamera }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        for input in session.inputs { session.removeInput(input) }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        if session.outputs.isEmpty {
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            ]
            output.setSampleBufferDelegate(self, queue: frameQueue)
            guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
            session.addOutput(output)
        }
        return device
    }

    /// Picks a format between 640×480 and 1280×720 with the highest frame rate (up to 60 fps).
    /// Higher frame rates lower latency; Vision doesn't need more resolution than that.
    private static func selectFastFormat(for device: AVCaptureDevice) {
        var best: (format: AVCaptureDevice.Format, fps: Double, width: Int32)?
        for format in device.formats {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard dims.width >= 640, dims.width <= 1280 else { continue }
            let maxFPS = min(format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0, 60)
            if let current = best {
                if maxFPS > current.fps || (maxFPS == current.fps && dims.width > current.width) {
                    best = (format, maxFPS, dims.width)
                }
            } else {
                best = (format, maxFPS, dims.width)
            }
        }
        guard let best, best.fps > 0 else { return }
        do {
            try device.lockForConfiguration()
            device.activeFormat = best.format
            let duration = CMTime(value: 1, timescale: CMTimeScale(best.fps.rounded(.down)))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
            // Keep whatever format the camera chose.
        }
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}
