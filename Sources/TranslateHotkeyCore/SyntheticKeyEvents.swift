import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

public enum SyntheticKeyEvents {
    /// Posts Cmd+C or Cmd+V using HID events (requires Accessibility permission for other apps).
    public static func postCommandKeypress(virtualKey: CGKeyCode, keyDown: Bool) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: keyDown) else { return }
        event.flags = .maskCommand
        event.post(tap: .cghidEventTap)
    }

    public static func copyChord() {
        postCommandKeypress(virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        postCommandKeypress(virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
    }

    public static func pasteChord() {
        postCommandKeypress(virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        postCommandKeypress(virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
    }

    public static func sleepMilliseconds(_ ms: Int) {
        usleep(useconds_t(ms * 1000))
    }
}
