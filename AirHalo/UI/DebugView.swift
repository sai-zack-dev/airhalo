import AirHaloBrain
@preconcurrency import AVFoundation
import SwiftUI

/// Camera preview with the tracked skeleton, live numbers, and session recording
/// for tuning and test fixtures.
struct DebugView: View {
    @Bindable var model: AppModel
    let delegate: AppDelegate
    let session: AVCaptureSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                CameraPreview(session: session, mirrored: model.settings.mirror)
                SkeletonOverlay(frame: model.lastFrame)
            }
            .aspectRatio(model.lastFrame?.aspect ?? 16.0 / 9.0, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    stat("State", model.isActive ? model.halo.mode.rawValue : "inactive")
                    stat("Hands", "\(model.lastFrame?.hands.count ?? 0)")
                    stat("FPS", String(format: "%.0f", model.fps))
                    stat("Latency", String(format: "%.0f ms", model.latencyMs))
                }
                .frame(width: 170, alignment: .leading)

                if let hand = model.lastFrame?.hands.first,
                   let metrics = HandMetrics(hand: hand, minConfidence: model.settings.brain.minJointConfidence) {
                    VStack(alignment: .leading, spacing: 4) {
                        stat("Pinch (index)", String(format: "%.2f", metrics.indexPinch))
                        stat("Pinch (middle)", String(format: "%.2f", metrics.middlePinch))
                        stat("Fingers", metrics.fingerExtension.map { String(format: "%.1f", $0) }.joined(separator: " "))
                        stat("Hand size", String(format: "%.3f", metrics.scale))
                    }
                } else {
                    Text("No hand").foregroundStyle(.secondary)
                }
                Spacer()
            }
            .font(.system(.callout, design: .monospaced))

            HStack {
                Button {
                    model.isRecording ? delegate.stopRecording() : delegate.startRecording()
                } label: {
                    Label(model.isRecording ? "Stop recording" : "Record", systemImage: model.isRecording ? "stop.circle.fill" : "record.circle")
                }
                .tint(model.isRecording ? .red : nil)

                if let url = model.lastRecordingURL {
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    Text(url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !model.settings.enabled {
                    Text("AirHalo is off: tracking only, the pointer won't move.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 520)
    }

    private func stat(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

/// Live camera image (mirrored to match the tracking coordinates).
private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = layer
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let connection = (view.layer as? AVCaptureVideoPreviewLayer)?.connection,
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }
}

/// Draws the 21 joints and the bones between them.
private struct SkeletonOverlay: View {
    let frame: HandFrame?

    private static let bones: [(Joint, Joint)] = {
        var bones: [(Joint, Joint)] = [(.wrist, .thumbCMC), (.thumbCMC, .thumbMCP), (.thumbMCP, .thumbIP), (.thumbIP, .thumbTip)]
        for finger in Finger.allCases {
            let base = finger.mcp.rawValue
            bones.append((.wrist, finger.mcp))
            for offset in 0..<3 {
                bones.append((Joint(rawValue: base + offset)!, Joint(rawValue: base + offset + 1)!))
            }
        }
        bones += [(.indexMCP, .middleMCP), (.middleMCP, .ringMCP), (.ringMCP, .littleMCP)]
        return bones
    }()

    var body: some View {
        Canvas { context, size in
            guard let frame else { return }
            func point(_ v: Vec2) -> CGPoint {
                CGPoint(x: v.x / frame.aspect * size.width, y: v.y * size.height)
            }
            for (index, hand) in frame.hands.enumerated() {
                let color: Color = index == 0 ? .teal : .orange
                var path = Path()
                for (a, b) in Self.bones where hand.confidence(a) > 0.3 && hand.confidence(b) > 0.3 {
                    path.move(to: point(hand[a]))
                    path.addLine(to: point(hand[b]))
                }
                context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 2)
                for joint in Joint.allCases where hand.confidence(joint) > 0.3 {
                    let p = point(hand[joint])
                    let r: CGFloat = joint == .thumbTip || joint == .indexTip ? 5 : 3
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
