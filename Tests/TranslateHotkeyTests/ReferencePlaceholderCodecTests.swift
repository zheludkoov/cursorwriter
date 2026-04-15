import Testing
import TranslateHotkeyCore

@Suite("ReferencePlaceholderCodec")
struct ReferencePlaceholderCodecTests {
    @Test("masks absolute @/ plan paths")
    func absolutePlanPath() throws {
        let path = "@/Users/rare/ghostics/ai_context/ai_antidote.md"
        let input = "See \(path) for context."
        let (masked, pairs) = ReferencePlaceholderCodec.maskReferences(in: input)
        #expect(masked.contains("⟦REF_"))
        #expect(!masked.contains("@/Users"))
        let translated = masked.replacingOccurrences(of: "See", with: "SEE")
        let restored = try ReferencePlaceholderCodec.restore(translated: translated, pairs: pairs)
        #expect(restored.contains(path))
    }

    @Test("masks relative repo paths with @")
    func relativeRepoPath() throws {
        let path = "@ai_context/ai_antidote.md"
        let input = "Open \(path) please."
        let (masked, pairs) = ReferencePlaceholderCodec.maskReferences(in: input)
        #expect(masked.contains("⟦REF_"))
        #expect(!masked.contains("ai_context"))
        let translated = masked.replacingOccurrences(of: "Open", with: "OPEN")
        let restored = try ReferencePlaceholderCodec.restore(translated: translated, pairs: pairs)
        #expect(restored.contains(path))
    }

    @Test("does not mask @Symbol without path slash")
    func ignoresBareAtSymbol() throws {
        let input = "See @Model and @ai_context/file.md"
        let (masked, pairs) = ReferencePlaceholderCodec.maskReferences(in: input)
        #expect(masked.contains("@Model"))
        #expect(pairs.count == 1)
        #expect(pairs[0].original == "@ai_context/file.md")
    }

    @Test("does not mask file:line or backticks")
    func ignoresFileLineAndBackticks() throws {
        let input = "Error in App.swift:42 and `README.md`."
        let (masked, pairs) = ReferencePlaceholderCodec.maskReferences(in: input)
        #expect(pairs.isEmpty)
        #expect(masked == input)
    }

    @Test("detects missing placeholders")
    func missing() {
        let pairs: [(token: String, original: String)] = [("⟦REF_0001⟧", "@x/y")]
        let translated = "no tokens here"
        let missing = ReferencePlaceholderCodec.missingPlaceholderTokens(in: translated, pairs: pairs)
        #expect(missing == ["⟦REF_0001⟧"])
    }

    @Test("restoreReplacingPresentOnly substitutes only tokens still in the text")
    func partialRestore() {
        let pairs: [(token: String, original: String)] = [
            ("⟦REF_0001⟧", "@a/b"),
            ("⟦REF_0002⟧", "@c/d"),
        ]
        let translated = "See ⟦REF_0001⟧ only."
        let out = ReferencePlaceholderCodec.restoreReplacingPresentOnly(translated: translated, pairs: pairs)
        #expect(out == "See @a/b only.")
    }

    @Test("Russian text with only Cursor path refs")
    func russianWithCursorRefs() throws {
        let input = "Смотри @ai_context/x.md и план @/Users/u/plan.md — важно."
        let (masked, pairs) = ReferencePlaceholderCodec.maskReferences(in: input)
        #expect(pairs.count == 2)
        let translated = masked.replacingOccurrences(of: "важно", with: "important")
        let restored = try ReferencePlaceholderCodec.restore(translated: translated, pairs: pairs)
        #expect(restored.contains("@ai_context/x.md"))
        #expect(restored.contains("@/Users/u/plan.md"))
    }
}
