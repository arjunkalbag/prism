import AppKit
import Carbon.HIToolbox

/// Global hotkeys via Carbon `RegisterEventHotKey` — works system-wide without
/// stealing focus. (A self-contained alternative to the KeyboardShortcuts
/// package; no external dependency to resolve.)
///
///   ⌃⌥K — show / hide the overlay
///   ⌃⌥T — toggle click-through
final class HotkeyManager {
    var onToggleVisibility: (@MainActor () -> Void)?
    var onToggleClickThrough: (@MainActor () -> Void)?

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var handlerRef: EventHandlerRef?

    func register() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            manager.handle(id: hkID.id)
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        registerHotKey(id: 1, keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey))
        registerHotKey(id: 2, keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | optionKey))
    }

    private func registerHotKey(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5052534D /* 'PRSM' */), id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr { hotKeyRefs.append(ref) }
    }

    private func handle(id: UInt32) {
        Task { @MainActor [weak self] in
            switch id {
            case 1: self?.onToggleVisibility?()
            case 2: self?.onToggleClickThrough?()
            default: break
            }
        }
    }

    deinit {
        for ref in hotKeyRefs { if let ref { UnregisterEventHotKey(ref) } }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
