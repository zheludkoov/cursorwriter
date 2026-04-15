import Carbon.HIToolbox
import Foundation

/// Registers a global hotkey (⌃⌥⌘T) using Carbon `RegisterEventHotKey`.
public final class HotkeyRegistrar: @unchecked Sendable {
    private static let signature: OSType = {
        let s = "THK1"
        var v: UInt32 = 0
        for u in s.utf8 { v = (v << 8) | UInt32(u) }
        return OSType(v)
    }()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    public var onHotkey: (() -> Void)?

    public init() {}

    deinit {
        unregister()
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    /// Installs the event handler and registers the hotkey. Returns `noErr` on success.
    @discardableResult
    public func install() -> OSStatus {
        unregister()

        var eventType = EventTypeSpec(eventClass: UInt32(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var handler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handlerUPP,
            1,
            &eventType,
            selfPtr,
            &handler
        )
        guard installStatus == noErr else { return installStatus }
        eventHandler = handler

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        var ref: EventHotKeyRef?
        let mods = UInt32(cmdKey | optionKey | controlKey)
        let regStatus = RegisterEventHotKey(UInt32(kVK_ANSI_T), mods, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard regStatus == noErr else {
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            return regStatus
        }
        hotKeyRef = ref
        return noErr
    }

    private static let handlerUPP: EventHandlerUPP = {
        typealias Callback = @convention(c) (EventHandlerCallRef?, EventRef?, UnsafeMutableRawPointer?) -> OSStatus
        let cb: Callback = { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            Unmanaged<HotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue().onHotkey?()
            return noErr
        }
        return cb as EventHandlerUPP
    }()
}
