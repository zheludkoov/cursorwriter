import AppKit
import Foundation
import OSLog

public enum TranslationRunOutcome: Sendable {
    case completed
    /// Clipboard was written; at least one `⟦REF_####⟧` token was absent from the model output so those paths were not restored.
    case completedWithMissingReferences
    case failed(String)
    case abortedConcurrent
}

private enum TranslationPrepareOutcome: Sendable {
    case success(apiKey: String, masked: String, pairs: [(token: String, original: String)])
    case failure(String)
}

extension TranslationRunner {
    /// Keychain, pasteboard read, and reference masking can block; run off the main actor so the UI stays responsive.
    nonisolated private static func prepareOffMain() async -> TranslationPrepareOutcome {
        await withCheckedContinuation { (continuation: CheckedContinuation<TranslationPrepareOutcome, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let outcome: TranslationPrepareOutcome
                if let apiKey = KeychainStore.loadAPIKey(), !apiKey.isEmpty {
                    let pb = NSPasteboard.general
                    if let selected = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !selected.isEmpty
                    {
                        let (masked, pairs) = ReferencePlaceholderCodec.maskReferences(in: selected)
                        outcome = .success(apiKey: apiKey, masked: masked, pairs: pairs)
                    } else {
                        outcome = .failure("Clipboard is empty. Copy text first, then press ⌃⌥⌘T.")
                    }
                } else {
                    outcome = .failure("Add your xAI API key in Settings (menu bar icon → Settings).")
                }
                // Do not resume via `DispatchQueue.main.async`: a time-driven MenuBarExtra label can starve the main
                // queue so the continuation never runs (deadlock + pegged CPU).
                continuation.resume(returning: outcome)
            }
        }
    }
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

        let prepared = await Self.prepareOffMain()
        let apiKey: String
        let masked: String
        let pairs: [(token: String, original: String)]
        switch prepared {
        case .failure(let message):
            return .failed(message)
        case .success(let k, let m, let p):
            apiKey = k
            masked = m
            pairs = p
        }

        let pb = NSPasteboard.general
        let client = GrokClient(apiKey: apiKey, model: UserSettings.selectedModel, session: urlSession)
        let system = UserSettings.systemPrompt

        do {
            let output = try await client.chatCompletion(system: system, user: masked)
            let missing = ReferencePlaceholderCodec.missingPlaceholderTokens(in: output, pairs: pairs)
            let finalText: String
            let outcome: TranslationRunOutcome
            if missing.isEmpty {
                finalText = try ReferencePlaceholderCodec.restore(translated: output, pairs: pairs)
                outcome = .completed
            } else {
                AppLog.general.warning("Missing placeholders after translation; copying partial result without repair. Missing: \(missing.joined(separator: ", "), privacy: .public)")
                finalText = ReferencePlaceholderCodec.restoreReplacingPresentOnly(translated: output, pairs: pairs)
                outcome = .completedWithMissingReferences
            }

            pb.clearContents()
            pb.setString(finalText, forType: .string)
            return outcome
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
