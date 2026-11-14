import SwiftUI

/// First-run setup: camera and Accessibility permission, then how to use it.
struct OnboardingView: View {
    @Bindable var model: AppModel
    let delegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "hand.raised.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to AirHalo").font(.title2.bold())
                    Text("Use your hand as a mouse and trackpad, with just your camera.")
                        .foregroundStyle(.secondary)
                }
            }

            PermissionRow(
                number: 1,
                title: "Camera",
                detail: "To see your hand. Video is processed on this Mac and never leaves it.",
                granted: model.cameraGranted,
                buttonTitle: Permissions.cameraStatus == .notDetermined ? "Allow Camera" : "Open Settings"
            ) {
                if Permissions.cameraStatus == .notDetermined {
                    Task {
                        _ = await Permissions.requestCamera()
                        model.refreshPermissions()
                        delegate.startCameraIfNeeded()
                    }
                } else {
                    Permissions.openCameraSettings()
                }
            }

            PermissionRow(
                number: 2,
                title: "Accessibility",
                detail: "To move the pointer, click and scroll. In System Settings, switch AirHalo on.",
                granted: model.accessibilityGranted,
                buttonTitle: "Open Settings"
            ) {
                Permissions.promptForAccessibility()
                Permissions.openAccessibilitySettings()
                delegate.startPermissionPolling()
            }

            GroupBox("How to use it") {
                VStack(alignment: .leading, spacing: 6) {
                    GestureRow(symbol: "hand.raised", text: "Show an open palm for a moment to start. The halo appears.")
                    GestureRow(symbol: "hand.point.up.left", text: "Move your hand to move the pointer.")
                    GestureRow(symbol: "hand.pinch", text: "Pinch thumb and index to click. Hold the pinch to drag.")
                    GestureRow(symbol: "hand.pinch.fill", text: "Pinch thumb and middle finger to right-click.")
                    GestureRow(symbol: "hand.point.up", text: "Raise index and middle finger, then move, to scroll.")
                    GestureRow(symbol: "hands.clap", text: "Pinch with both hands and pull apart to zoom.")
                    GestureRow(symbol: "arrow.left.and.right", text: "Flick your open hand sideways to switch Space.")
                    GestureRow(symbol: "hand.raised.slash", text: "Make a fist, or drop your hand, to stop.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            Spacer(minLength: 0)

            HStack {
                Text("\(Hotkey.displayString) turns AirHalo on or off at any time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Start AirHalo") {
                    delegate.startCameraIfNeeded()
                    delegate.windows.closeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.permissionsOK)
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 540)
    }
}

private struct PermissionRow: View {
    let number: Int
    let title: String
    let detail: String
    let granted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title2)
                .foregroundStyle(granted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted {
                Text("Allowed").foregroundStyle(.green)
            } else {
                Button(buttonTitle, action: action)
            }
        }
    }
}

private struct GestureRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).frame(width: 22)
        }
    }
}
