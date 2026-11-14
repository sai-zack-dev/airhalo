import Carbon.HIToolbox

/// A system-wide keyboard shortcut (Carbon hot keys need no extra permission).
@MainActor
final class Hotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void

    /// Default: ⌃⌥Space.
    init(keyCode: Int = kVK_Space, modifiers: Int = controlKey | optionKey, action: @escaping @MainActor () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotkey = Unmanaged<Hotkey>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { hotkey.action() }
            return noErr
        }, 1, &eventType, context, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x4149_5248), id: 1)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    // Lives for the whole app session, so it never unregisters.

    static let displayString = "⌃⌥Space"
}
