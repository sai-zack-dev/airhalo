import AirHaloBrain
import AppKit
import QuartzCore

/// The halo: a ring that follows the pointer while AirHalo is engaged.
/// It shrinks as your pinch closes, so you can see a click coming, and changes
/// colour for drag, right click, scroll and zoom. Clicks pass straight through it.
@MainActor
final class HaloOverlay: NSObject {
    private let size: CGFloat = 96
    private let panel: NSPanel
    private let outline = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let fill = CAShapeLayer()
    private var displayLink: CADisplayLink?
    private var state = HaloState.hidden
    private var isShown = false

    override init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        let view = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        panel.contentView = view

        for layer in [fill, outline, ring] {
            layer.frame = view.bounds
            layer.fillColor = nil
            layer.lineCap = .round
            view.layer?.addSublayer(layer)
        }
        outline.strokeColor = NSColor.black.withAlphaComponent(0.35).cgColor
        outline.lineWidth = 5.5
        ring.lineWidth = 3
        panel.alphaValue = 0
    }

    func update(_ newState: HaloState) {
        state = newState
        let shouldShow = newState.mode != .hidden
        if shouldShow != isShown { setShown(shouldShow) }
        guard shouldShow else { return }
        redraw()
    }

    func hide() { update(.hidden) }

    private func setShown(_ show: Bool) {
        isShown = show
        if show {
            followPointer()
            panel.orderFrontRegardless()
            startDisplayLink()
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = show ? 0.12 : 0.25
            panel.animator().alphaValue = show ? 1 : 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isShown else { return }
                self.panel.orderOut(nil)
                self.displayLink?.invalidate()
                self.displayLink = nil
            }
        })
    }

    private func redraw() {
        let center = CGPoint(x: size / 2, y: size / 2)
        let maxRadius: CGFloat = 28
        let minRadius: CGFloat = 11

        var radius = maxRadius - (maxRadius - minRadius) * CGFloat(state.pinchProgress)
        var color = NSColor.systemTeal
        var dashed = false
        var filled = false
        var strokeEnd: CGFloat = 1

        switch state.mode {
        case .hidden:
            return
        case .arming:
            color = .white
            strokeEnd = CGFloat(state.armingProgress)
            radius = maxRadius
        case .hover:
            break
        case .pressed:
            radius = minRadius
            filled = true
        case .dragging:
            radius = minRadius + 3
            filled = true
            color = .systemOrange
        case .rightPressed:
            radius = minRadius
            filled = true
            color = .systemPurple
        case .scrolling:
            radius = maxRadius - 6
            color = .systemBlue
            dashed = true
        case .zooming:
            radius = maxRadius
            color = .systemYellow
            dashed = true
        }

        // Start at 12 o'clock and go clockwise, so arming fills like a timer.
        let path = CGMutablePath()
        path.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.08)
        for layer in [outline, ring] {
            layer.path = path
            layer.strokeEnd = strokeEnd
            layer.lineDashPattern = dashed ? [6, 5] : nil
        }
        ring.strokeColor = color.cgColor
        fill.path = filled ? CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil) : nil
        fill.fillColor = color.withAlphaComponent(0.3).cgColor
        CATransaction.commit()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = panel.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        followPointer()
    }

    private func followPointer() {
        let mouse = NSEvent.mouseLocation  // bottom-left origin, same as window frames
        panel.setFrameOrigin(NSPoint(x: mouse.x - size / 2, y: mouse.y - size / 2))
    }
}
