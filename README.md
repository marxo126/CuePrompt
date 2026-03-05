# CuePrompt

An open-source teleprompter app for macOS and iOS.

## Features

- **Rich Text Editor** - Bold, italic, underline, font size, text color, highlight, and alignment formatting
- **Floating Window** (macOS) - Always-on-top teleprompter panel with adjustable opacity, resizable and movable
- **Auto-Scrolling** - Smooth programmatic scrolling via native ScrollPosition API with adjustable speed (0.5x to 5x)
- **Manual Scroll Sync** - Pause and manually reposition; resume picks up exactly where you left off
- **Built-in Timer** - Count-up and countdown modes with configurable warning threshold
- **Inline Cues** - Add cues with `[CUE: your note]` syntax that render distinctly in the teleprompter
- **Script Management** - Create, edit, delete scripts with SwiftData persistence and rich text (RTFD) storage
- **Mirror Mode** - Horizontal flip for glass teleprompter setups
- **Keyboard Shortcuts** - Space (play/pause), arrows (speed), R (reset), M (mirror), Escape (close)
- **Customizable** - Font size, colors, line spacing, margins, background, and more via Settings

## Requirements

- iOS 26+ / macOS 26+
- Xcode 26+ with Swift 6

## Getting Started

1. Clone the repository
2. Open `CuePrompt.xcodeproj` in Xcode
3. Select your target (macOS or iOS)
4. Build and run

## Architecture

| Layer | Files |
|-------|-------|
| App entry | `CuePromptApp.swift` |
| Models | `Script.swift`, `AppSettings.swift` |
| ViewModels | `TeleprompterViewModel.swift`, `ScriptStore.swift` |
| Views | `ContentView`, `ScriptEditorView`, `RichTextEditor`, `FormattingToolbar` |
| Teleprompter | `TeleprompterContentView`, `TransportControlsView`, `TimerView`, `CenterLineIndicator` |
| macOS | `FloatingPanelManager` (NSPanel-based floating window) |
| iOS | `TeleprompterView` (fullScreenCover) |
| Utilities | `KeyboardShortcuts` (shared keyboard modifier) |

## License

Non-Commercial Open Source — free to use, modify, and distribute for non-commercial purposes. See [LICENSE](LICENSE) for details.
