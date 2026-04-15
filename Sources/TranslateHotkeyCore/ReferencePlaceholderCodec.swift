import Foundation
import OSLog

/// Masks **Cursor file references** copied as plain text: `@/absolute/...` (plans) and `@relative/path` (repo files).
/// Replaced spans are restored verbatim after translation.
public enum ReferencePlaceholderCodec {
    private static let placeholderPrefix = "⟦REF_"
    private static let placeholderSuffix = "⟧"

    private struct Span {
        let range: Range<String.Index>
        let original: String
    }

    /// Masks Cursor `@` path references. Returns masked text and ordered (token, original) pairs for restoration.
    public static func maskReferences(in text: String) -> (masked: String, pairs: [(token: String, original: String)]) {
        let spans = collectCandidates(in: text).sorted { $0.range.lowerBound < $1.range.lowerBound }
        guard !spans.isEmpty else { return (text, []) }

        var pairs: [(String, String)] = []
        pairs.reserveCapacity(spans.count)
        var result = ""
        var cursor = text.startIndex
        var index = 1
        for span in spans {
            if cursor < span.range.lowerBound {
                result.append(contentsOf: text[cursor..<span.range.lowerBound])
            }
            let token = String(format: "%@%04d%@", placeholderPrefix, index, placeholderSuffix)
            index += 1
            result.append(token)
            pairs.append((token: token, original: span.original))
            cursor = span.range.upperBound
        }
        if cursor < text.endIndex {
            result.append(contentsOf: text[cursor...])
        }
        return (result, pairs)
    }

    /// Replaces every known placeholder token with its original span. Fails if any placeholder is missing from `translated`.
    public static func restore(translated: String, pairs: [(token: String, original: String)]) throws -> String {
        let missing = pairs.filter { !translated.contains($0.token) }.map(\.token)
        guard missing.isEmpty else {
            AppLog.codec.error("Missing placeholders: \(missing.joined(separator: ", "), privacy: .public)")
            throw CodecError.missingPlaceholders(missing)
        }
        var out = translated
        for (token, original) in pairs {
            out = out.replacingOccurrences(of: token, with: original)
        }
        return out
    }

    public static func missingPlaceholderTokens(in translated: String, pairs: [(token: String, original: String)]) -> [String] {
        pairs.filter { !translated.contains($0.token) }.map(\.token)
    }

    public enum CodecError: Error, LocalizedError, Sendable {
        case missingPlaceholders([String])

        public var errorDescription: String? {
            switch self {
            case .missingPlaceholders(let tokens):
                return "Model output dropped required reference tokens: \(tokens.joined(separator: ", "))"
            }
        }
    }

    private static func collectCandidates(in text: String) -> [Span] {
        var spans: [Span] = []
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)

        // 1) Plans / absolute: @/Users/.../file.md
        // 2) Repo relative: @ai_context/ai_antidote.md (must contain `/` after `@`, not `@/`).
        let patterns: [(String, NSRegularExpression.Options)] = [
            (#"@/[^\s,\]}\)>]+"#, []),
            (#"@(?![/])(?:[^\s,\]}\)>]+/)+[^\s,\]}\)>]+"#, [])
        ]

        for (pattern, opts) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: opts) else { continue }
            regex.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
                guard let match, match.range.length > 0 else { return }
                guard let range = Range(match.range, in: text) else { return }
                let slice = String(text[range])
                if !slice.isEmpty { spans.append(Span(range: range, original: slice)) }
            }
        }
        return spans
    }
}
