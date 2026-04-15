import AppKit
import SwiftUI
import TranslateHotkeyCore

struct SettingsView: View {
    @AppStorage(UserSettings.systemPromptKey) private var systemPrompt: String = UserSettings.defaultSystemPrompt
    @AppStorage(UserSettings.modelKey) private var model: String = UserSettings.grokModels[0].id

    @State private var apiKeyField = ""
    @State private var saveMessage: String?

    var body: some View {
        Form {
            Section("System prompt") {
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(minHeight: 160)
            }

            Section("Model") {
                Picker("Grok model", selection: $model) {
                    ForEach(UserSettings.grokModels, id: \.id) { entry in
                        Text(entry.label).tag(entry.id)
                    }
                }
                .labelsHidden()
            }

            Section("API key") {
                SecureField("xAI API key", text: $apiKeyField)
                HStack {
                    Button("Save API key") {
                        saveAPIKey()
                    }
                    if let saveMessage {
                        Text(saveMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                LabeledContent("Global shortcut") {
                    Text("⌃⌥⌘T")
                        .font(.system(.body, design: .monospaced))
                }
                Text("Copy text, press the shortcut to translate the clipboard, then paste where you need it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
            apiKeyField = KeychainStore.loadAPIKey() ?? ""
            if !UserSettings.grokModels.contains(where: { $0.id == model }) {
                model = UserSettings.grokModels[0].id
            }
        }
    }

    private func saveAPIKey() {
        do {
            if apiKeyField.isEmpty {
                KeychainStore.deleteAPIKey()
                saveMessage = "Removed API key."
            } else {
                try KeychainStore.saveAPIKey(apiKeyField)
                saveMessage = "Saved API key."
            }
        } catch {
            saveMessage = error.localizedDescription
        }
    }
}
