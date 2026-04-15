import AppKit
import Foundation
import OSLog

public enum TranslationRunOutcome: Sendable {
    case completed
    case failed(String)
    case abortedConcurrent
}

@MainActor
public final class TranslationRunner {
    private var inFlight = false

    public var isTranslationInFlight: Bool { inFlight }

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }()

    public init() {}

    public func run() async -> TranslationRunOutcome {
        guard !inFlight else {
            AppLog.general.warning("Ignored hotkey re-entrancy while a translation is in flight.")
            return .abortedConcurrent
        }
        inFlight = true
        defer { inFlight = false }

        guard let apiKey = KeychainStore.loadAPIKey(), !apiKey.isEmpty else {
            return .failed("Add your xAI API key in Settings (menu bar icon → Settings).")
        }

        let pb = NSPasteboard.general
        guard let selected = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selected.isEmpty
        else {
            return .failed("Clipboard is empty. Copy text first, then press ⌃⌥⌘T.")
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
            return .completed
        } catch {
            return .failed(error.localizedDescription)
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
}
