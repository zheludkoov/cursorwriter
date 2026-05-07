#### Run the program in the terminal
`swift run TranslateHotkey`

### A pure Swift MacOS app to process text from the clipboard using AI
I use this for improving and processing prompts in Cursor and translate text in Figma.

1. You write a basic prompt for text editing (translation, improvement, editing).
2. Enter your API key (now Grok only).
3. In any program (Cursor, Figma, etc.), you copy text from the field into the clipboard.
4. You press the hotkey `Control Option Command T`.
5. Wait for completion — the icon in the tray will change to a checkmark.
6. Paste the processed text back into the field in place of the old one.

### AI list
Now only Grok latest and fast

### Why I made it exactly like this
No need to grant any special permissions to the program; it only works with the clipboard. This allows it to work everywhere without integration into the operating system or into programs.

### Plans
In the future I might make a full-fledged App so I don't have to run it through the terminal.
