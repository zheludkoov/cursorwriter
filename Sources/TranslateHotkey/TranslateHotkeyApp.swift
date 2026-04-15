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
            // Static icon: time-driven `TimelineView` in a MenuBarExtra label can starve `main` and deadlock clipboard prep.
            Image(systemName: "arrow.triangle.2.circlepath")
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.green)
        case .successWithWarning:
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.yellow)
        }
    }
}
