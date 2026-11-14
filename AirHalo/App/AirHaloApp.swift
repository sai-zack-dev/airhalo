import SwiftUI

@main
struct AirHaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: appDelegate.model, delegate: appDelegate)
        } label: {
            Image(systemName: appDelegate.model.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
