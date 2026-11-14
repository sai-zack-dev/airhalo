import AirHaloBrain
import CoreVideo
import Vision

/// Runs Apple Vision's hand-pose model and converts the result into the brain's
/// platform-independent `HandFrame` (MediaPipe joint order, selfie-mirrored,
/// units of image height, origin top-left).
final class VisionHandTracker {
    private let request: VNDetectHumanHandPoseRequest

    /// Vision joint names in `Joint` (MediaPipe) order.
    private let jointOrder: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    init() {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
    }

    func track(_ pixelBuffer: CVPixelBuffer, timestamp: Double, mirrored: Bool) -> HandFrame {
        let width = Double(CVPixelBufferGetWidth(pixelBuffer))
        let height = Double(CVPixelBufferGetHeight(pixelBuffer))
        let aspect = height > 0 ? width / height : 16.0 / 9.0

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return HandFrame(timestamp: timestamp, aspect: aspect, hands: [])
        }

        let hands = (request.results ?? []).compactMap { observation -> Hand? in
            guard let recognized = try? observation.recognizedPoints(.all) else { return nil }
            let points = jointOrder.map { name -> HandPoint in
                guard let point = recognized[name], point.confidence > 0 else {
                    return HandPoint(.zero, confidence: 0)
                }
                // Vision: normalized, origin bottom-left. Brain: origin top-left, mirrored, units of height.
                var x = Double(point.location.x)
                if mirrored { x = 1 - x }
                let y = 1 - Double(point.location.y)
                return HandPoint(Vec2(x * aspect, y), confidence: Double(point.confidence))
            }
            return Hand(chirality: Self.chirality(observation.chirality), points: points)
        }
        return HandFrame(timestamp: timestamp, aspect: aspect, hands: hands)
    }

    private static func chirality(_ value: VNChirality) -> AirHaloBrain.Chirality {
        switch value {
        case .left: .left
        case .right: .right
        default: .unknown
        }
    }
}
