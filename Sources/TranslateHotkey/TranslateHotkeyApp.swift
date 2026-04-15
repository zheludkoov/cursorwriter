import AppKit
import SwiftUI
import TranslateHotkeyCore

@main
struct TranslateHotkeyApp: App {
    @StateObject private var appState = AppState()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            Button("Translate clipboard") {
                Task { await appState.translateClipboard() }
            }
            Divider()
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            trayIcon
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }

    @ViewBuilder
    private var trayIcon: some View {
        switch appState.trayPhase {
        case .idle:
            Image(systemName: "doc.on.clipboard")
        case .working:
            Image(systemName: "arrow.triangle.2.circlepath")
                .symbolEffect(.rotate, options: .repeating, isActive: true)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.green)
        }
    }
}
