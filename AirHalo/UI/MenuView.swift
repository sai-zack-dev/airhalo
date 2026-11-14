import SwiftUI

/// The panel that opens from the menu bar icon.
struct MenuView: View {
    @Bindable var model: AppModel
    let delegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: model.menuBarSymbol)
                    .font(.title2)
                    .foregroundStyle(model.isActive ? Color.teal : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AirHalo").font(.headline)
                    Text(model.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $model.settings.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("Turn AirHalo on or off (\(Hotkey.displayString))")
            }

            if !model.permissionsOK {
                Button("Set up permissions…") { delegate.windows.showOnboarding() }
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Pointer speed").font(.caption).foregroundStyle(.secondary)
                Slider(value: $model.settings.brain.sensitivity, in: 0.3...3)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Smoothing").font(.caption).foregroundStyle(.secondary)
                Slider(value: $model.settings.brain.smoothing, in: 0...1)
            }

            Divider()

            HStack {
                Button("Settings…") { delegate.windows.showSettings() }
                Button("Debug…") { delegate.windows.showDebug() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)

            Text("\(Hotkey.displayString) turns AirHalo on or off")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(width: 300)
    }
}
