import AppKit
import ApplicationServices
import Foundation
import OSLog

@MainActor
public final class TranslationRunner {
    private var inFlight = false

    public var onError: ((String) -> Void)?
    public var onSuccess: (() -> Void)?

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }()

    public init() {}

    public static func promptAccessibilityIfNeeded() {
        // String literal avoids Swift 6 concurrency warnings on `kAXTrustedCheckOptionPrompt`.
        let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public func run() async {
        guard !inFlight else {
            AppLog.general.warning("Ignored hotkey re-entrancy while a translation is in flight.")
            return
        }
        inFlight = true
        defer { inFlight = false }

        guard AXIsProcessTrusted() else {
            Self.promptAccessibilityIfNeeded()
            onError?("TranslateHotkey needs Accessibility permission (System Settings → Privacy & Security → Accessibility).")
            return
        }

        guard let apiKey = KeychainStore.loadAPIKey(), !apiKey.isEmpty else {
            onError?("Add your xAI API key in Settings (menu bar icon → Settings).")
            return
        }

        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)

        SyntheticKeyEvents.copyChord()
        SyntheticKeyEvents.sleepMilliseconds(200)

        guard let selected = pb.string(forType: .string), !selected.isEmpty else {
            restorePasteboard(pb, previous: previous)
            onError?("No text was copied. Select text in the editor, then press ⌃⌥⌘T.")
            return
        }

        let (masked, pairs) = ReferencePlaceholderCodec.maskReferences(in: selected)
        let client = GrokClient(apiKey: apiKey, model: UserSettings.selectedModel, session: urlSession)
        let system = UserSettings.systemPrompt

        do {
            var output = try await client.chatCompletion(system: system, user: masked)
            let missing = ReferencePlaceholderCodec.missingPlaceholderTokens(in: output, pairs: pairs)
            if !missing.isEmpty {
                AppLog.general.warning("Missing placeholders after first pass; attempting one repair call.")
                output = try await repairMissingOutput(
                    output: output,
                    missing: missing,
                    pairs: pairs,
                    client: client
                )
            }
            let finalText = try ReferencePlaceholderCodec.restore(translated: output, pairs: pairs)

            pb.clearContents()
            pb.setString(finalText, forType: .string)
            SyntheticKeyEvents.sleepMilliseconds(50)
            SyntheticKeyEvents.pasteChord()
            SyntheticKeyEvents.sleepMilliseconds(150)
            restorePasteboard(pb, previous: previous)
            onSuccess?()
        } catch {
            restorePasteboard(pb, previous: previous)
            onError?(error.localizedDescription)
        }
    }

    private func repairMissingOutput(
        output: String,
        missing: [String],
        pairs: [(token: String, original: String)],
        client: GrokClient
    ) async throws -> String {
        let mapLines = pairs.map { "\($0.token) => \($0.original)" }.joined(separator: "\n")
        let user = """
        The following REFERENCE TOKENS must appear verbatim in the translated text but are MISSING from your draft:
        \(missing.joined(separator: ", "))

        Canonical mapping (token to original — copy tokens exactly, do not translate them):
        \(mapLines)

        Your previous draft (output ONLY the corrected full translation, no explanations):
        \(output)
        """
        let repairSystem = "Restore every ⟦REF_####⟧ token exactly as listed. Output only the corrected full text."
        return try await client.chatCompletion(system: repairSystem, user: user)
    }

    private func restorePasteboard(_ pb: NSPasteboard, previous: String?) {
        pb.clearContents()
        if let previous {
            pb.setString(previous, forType: .string)
        }
    }
}
