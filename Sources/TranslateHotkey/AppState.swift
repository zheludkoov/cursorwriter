import AppKit
import Carbon.HIToolbox
import SwiftUI
import TranslateHotkeyCore

enum TrayPhase: Equatable {
    case idle
    case working
    case success
}

@MainActor
final class AppState: ObservableObject {
    let runner = TranslationRunner()
    private let hotkey = HotkeyRegistrar()

    @Published private(set) var trayPhase: TrayPhase = .idle

    private var successResetTask: Task<Void, Never>?

    init() {
        hotkey.onHotkey = { [weak self] in
            guard let self else { return }
            Task { await self.translateClipboard() }
        }

        let status = hotkey.install()
        if status != noErr {
            AppLog.general.error("Hotkey registration failed with status \(status, privacy: .public).")
        }
    }

    func translateClipboard() async {
        cancelSuccessReset()
        guard !runner.isTranslationInFlight else { return }
        trayPhase = .working

        let outcome = await runner.run()
        switch outcome {
        case .completed:
            trayPhase = .success
            scheduleSuccessReset()
        case .failed(let message):
            trayPhase = .idle
            presentErrorAlert(message)
        case .abortedConcurrent:
            break
        }
    }

    private func cancelSuccessReset() {
        successResetTask?.cancel()
        successResetTask = nil
    }

    private func scheduleSuccessReset() {
        cancelSuccessReset()
        successResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            trayPhase = .idle
            successResetTask = nil
        }
    }

    private func presentErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "TranslateHotkey"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
