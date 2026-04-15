import Foundation

public enum UserSettings {
    public static let systemPromptKey = "systemPrompt"
    public static let modelKey = "selectedGrokModel"

    public static let defaultSystemPrompt = """
    You are an experienced software developer. Translate the user's text from Russian to English the way a senior engineer would write it: natural, precise, and idiomatic. Preserve every technical detail, nuance, tone, and ambiguity.

    The text may contain opaque placeholder tokens like ⟦REF_0001⟧. You MUST copy every such token into the translated output in the correct positions. Do not translate, rename, renumber, or drop these tokens.
    """

    public static let grokModels: [(id: String, label: String)] = [
        ("grok-4-latest", "Grok latest"),
        ("grok-4-1-fast-non-reasoning", "Grok fast (cheap)"),
    ]

    public static var systemPrompt: String {
        get {
            let v = UserDefaults.standard.string(forKey: systemPromptKey)
            return (v?.isEmpty == false) ? v! : defaultSystemPrompt
        }
        set { UserDefaults.standard.set(newValue, forKey: systemPromptKey) }
    }

    public static var selectedModel: String {
        get {
            let v = UserDefaults.standard.string(forKey: modelKey)
            if let v, grokModels.contains(where: { $0.id == v }) { return v }
            return grokModels.first?.id ?? "grok-4-latest"
        }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }
}
