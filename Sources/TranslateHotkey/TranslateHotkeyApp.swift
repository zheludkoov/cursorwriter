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
        MenuBarExtra("Translate", systemImage: "character.book.closed") {
            Button("Translate selection") {
                Task { await appState.runner.run() }
            }
            Divider()
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}
