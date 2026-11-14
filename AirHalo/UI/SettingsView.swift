import AirHaloBrain
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var spaceShortcutsOn = Permissions.spaceShortcutsEnabled

    var body: some View {
        Form {
            Section("Pointer") {
                Picker("Mode", selection: $model.settings.brain.pointerMode) {
                    Text("Trackpad (relative)").tag(PointerMode.relative)
                    Text("Pointing (absolute)").tag(PointerMode.absolute)
                }
                LabeledSlider("Speed", value: $model.settings.brain.sensitivity, range: 0.3...3)
                LabeledSlider("Smoothing", value: $model.settings.brain.smoothing, range: 0...1,
                              help: "More smoothing removes shake but adds a little lag.")
                Toggle("Glide between camera frames", isOn: $model.settings.smoothPointer)
            }

            Section("Gestures") {
                Toggle("Scroll (index + middle finger up)", isOn: $model.settings.brain.scrollEnabled)
                if model.settings.brain.scrollEnabled {
                    LabeledSlider("Scroll speed", value: $model.settings.brain.scrollGain, range: 800...6000)
                    Toggle("Natural scrolling", isOn: $model.settings.brain.naturalScroll)
                }
                Toggle("Zoom (pinch with both hands)", isOn: $model.settings.brain.zoomEnabled)
                Toggle("Switch Space (flick sideways)", isOn: $model.settings.brain.swipeEnabled)
                if model.settings.brain.swipeEnabled, !spaceShortcutsOn {
                    HStack {
                        Label("“Move left/right a space” (⌃← ⌃→) is turned off in Keyboard Shortcuts.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.callout)
                        Button("Open") { Permissions.openKeyboardShortcutsSettings() }
                    }
                }
                LabeledSlider("Click sensitivity", value: pinchBinding, range: 0.15...0.4,
                              help: "How close thumb and finger must get to count as a pinch.")
            }

            Section("Camera") {
                Picker("Camera", selection: $model.settings.cameraID) {
                    Text("Default").tag(String?.none)
                    ForEach(model.cameras) { camera in
                        Text(camera.name).tag(Optional(camera.id))
                    }
                }
                Toggle("Mirror (front-facing camera)", isOn: $model.settings.mirror)
            }

            Section("Auto-pause") {
                Toggle("Pause while I use the mouse, trackpad or keyboard", isOn: $model.settings.pauseOnRealInput)
                Toggle("Pause during video calls", isOn: $model.settings.pauseForVideoCalls)
            }

            Section {
                HStack {
                    Text("On/off shortcut")
                    Spacer()
                    Text(Hotkey.displayString).foregroundStyle(.secondary)
                }
                Button("Reset gesture tuning to defaults") {
                    model.settings.brain = BrainSettings()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 600)
        .onAppear {
            model.cameras = CameraService.availableCameras()
            spaceShortcutsOn = Permissions.spaceShortcutsEnabled
        }
    }

    /// One slider for the pinch: open threshold stays a fixed step above close, for hysteresis.
    private var pinchBinding: Binding<Double> {
        Binding(
            get: { model.settings.brain.pinchClose },
            set: { value in
                model.settings.brain.pinchClose = value
                model.settings.brain.pinchOpen = value + 0.15
            }
        )
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var help: String?

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, help: String? = nil) {
        self.title = title
        _value = value
        self.range = range
        self.help = help
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Slider(value: $value, in: range)
            }
            if let help {
                Text(help).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
