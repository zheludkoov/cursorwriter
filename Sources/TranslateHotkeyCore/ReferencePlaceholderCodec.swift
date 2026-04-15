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

    /// Same boundaries as the old regex `[^\s,\]}\)>]+` — linear-time scan (avoids catastrophic backtracking on `@token` without `/`).
    private static func isPathTerminator(_ c: Character) -> Bool {
        if c.isWhitespace { return true }
        switch c {
        case ",", "]", "}", ")", ">": return true
        default: return false
        }
    }

    private static func collectCandidates(in text: String) -> [Span] {
        var spans: [Span] = []
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] != "@" {
                text.formIndex(after: &i)
                continue
            }
            let afterAt = text.index(after: i)
            if afterAt >= text.endIndex {
                text.formIndex(after: &i)
                continue
            }
            // 1) Plans / absolute: @/Users/.../file.md
            if text[afterAt] == "/" {
                let start = i
                var j = afterAt
                while j < text.endIndex, !isPathTerminator(text[j]) {
                    text.formIndex(after: &j)
                }
                if j > start {
                    let range = start..<j
                    spans.append(Span(range: range, original: String(text[range])))
                }
                i = j
                continue
            }
            // 2) Repo relative: @ai_context/file.md — must contain `/` before terminator (not `@/`).
            var j = afterAt
            var sawSlash = false
            while j < text.endIndex, !isPathTerminator(text[j]) {
                if text[j] == "/" { sawSlash = true }
                text.formIndex(after: &j)
            }
            if sawSlash, j > i {
                let range = i..<j
                spans.append(Span(range: range, original: String(text[range])))
            }
            i = j
        }
        return spans
    }
}
