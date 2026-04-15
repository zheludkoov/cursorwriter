# TranslateHotkey — context for AI assistants

## What it is

**TranslateHotkey** is a small macOS menu bar utility (Swift / SwiftUI, accessory app) that **reads plain text from the system clipboard**, **sends it to a language model for transformation** (currently translation / rewriting according to a system prompt), and **writes the model’s reply back to the clipboard** so the user can paste it elsewhere.

## How the user runs it

1. Copy the text to translate (or otherwise transform).
2. Trigger translation via **global shortcut ⌃⌥⌘T** (Control + Option + Command + T) or **Menu bar → “Translate clipboard”**.
3. Wait for completion (menu bar icon shows working / success states).
4. Paste the result from the clipboard.

If the clipboard has no string content, or the xAI API key is missing, the app shows an error instead of calling the API.

## Backend / provider

- **Only xAI Grok** is implemented today, via **`POST https://api.x.ai/v1/chat/completions`** (OpenAI-style chat payload: system + user messages, configurable model id, temperature ~0.3).
- The user’s **xAI API key** is stored in the **Keychain** and entered in **Settings**.
- Settings also expose **editable system prompt** and a **Grok model picker** (e.g. latest vs fast preset).

## App Sandbox and signing

- **Sandbox** is enabled in `TranslateHotkey.entitlements` (`com.apple.security.app-sandbox`, plus `com.apple.security.network.client` for Grok HTTPS). Unsigned `swift run` builds do **not** load those entitlements; use a signed binary for real sandbox behavior.
- **CLI signing:** from the repo root, run `./scripts/codesign-release.sh` (optional `CODESIGN_IDENTITY` for Developer ID). Defaults to ad-hoc `-` for local checks.
- **Xcode:** set **Code Signing Entitlements** on the TranslateHotkey executable to `TranslateHotkey.entitlements` so archives match the script.

### Upgrading from a non-sandbox build

Users who previously ran an **unsigned** or **non-sandbox** build may need to **enter the xAI API key again** in Settings (Keychain items can be scoped differently once sandbox + signing apply). **UserDefaults** (system prompt, model) may also appear reset because preferences move into the app **container** instead of the global preferences domain.

### Manual QA after a signed build

Use a binary produced by `./scripts/codesign-release.sh` (or an equivalent Xcode-signed build). Confirm: outbound translation to Grok works; empty clipboard shows the expected error; API key save/load survives quit and relaunch; ⌃⌥⌘T fires when another app is frontmost; custom system prompt and model choice persist across relaunch.

## Notable implementation details

- **Reference masking:** Before sending text to the model, **Cursor-style file references** in the clipboard (plain-text `@/absolute/...` and certain `@repo/path` forms) are replaced with opaque placeholders like `⟦REF_0001⟧`. The default system prompt instructs the model to preserve those tokens. After the reply, placeholders are **restored to the original paths** wherever they still appear. If the model drops some tokens, the clipboard still receives the partial result (remaining `⟦REF_####⟧` tokens are not rewritten), and the menu bar icon shows a **warning** instead of the success checkmark.
- **Concurrency:** Re-entrant hotkey presses while a run is in flight are ignored.
- **Defaults:** The bundled default system prompt targets **Russian → English** for technical writing, but the user can change this freely in Settings.
