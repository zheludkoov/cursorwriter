import AppKit
import Carbon.HIToolbox
import SwiftUI
import TranslateHotkeyCore

@MainActor
final class AppState: ObservableObject {
    let runner = TranslationRunner()
    private let hotkey = HotkeyRegistrar()

    init() {
        TranslationRunner.promptAccessibilityIfNeeded()

        runner.onError = { message in
            let alert = NSAlert()
            alert.messageText = "TranslateHotkey"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }

        hotkey.onHotkey = { [weak self] in
            guard let self else { return }
            Task { await self.runner.run() }
        }

        let status = hotkey.install()
        if status != noErr {
            AppLog.general.error("Hotkey registration failed with status \(status, privacy: .public).")
        }
    }
}
