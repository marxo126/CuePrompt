# Changelog

## [Unreleased]

### Added
- Rich text editor with formatting toolbar (bold, italic, underline, font size, text color, highlight, alignment)
- RTFD storage for attributed text in scripts
- `TeleprompterContentView` — extracted reusable scroll content with `ScrollPosition` API
- `TransportControlsView` — extracted reusable transport buttons (reset, speed, play/pause, mirror)
- `FormattingToolbar` — toolbar for rich text formatting actions
- `RichTextEditor` — NSTextView (macOS) / UITextView (iOS) representable with formatting support
- RTFD save debouncing (0.3s) to avoid expensive serialization on every keystroke
- `onDisappear` timer cleanup to prevent leaked 60fps timers
- UserDefaults key constants (`AppSettings.Key`) to prevent typos
- Speed range constants (`AppSettings.speedMin/speedMax/speedStep`) shared between ViewModel and Settings
- `timerWarningThreshold` now wired from AppSettings to ViewModel

### Changed
- macOS teleprompter opens as floating always-on-top NSPanel instead of modal sheet
- Teleprompter scrolling uses native `ScrollPosition` + `onScrollGeometryChange` instead of `ScrollView` + `.offset()` hack
- Combined two `onScrollGeometryChange` observers into one using `ScrollMetrics` struct
- Keyboard shortcuts consolidated into single `TeleprompterKeyboardModifier` shared by all teleprompter views
- Deployment targets bumped to macOS 26 / iOS 26
- Swift language version bumped to 6.0
- `ScriptSegment.id` changed from `String` to `Int` for efficiency
- `isDefaultLabelColor` now evaluates dynamically (fixes dark mode)
- Settings environment propagated from App level via `.environment()`

### Removed
- `CueNote.swift` model (unused, replaced by inline `[CUE:]` parsing)
- `ContentHeightKey` PreferenceKey (replaced by `onScrollGeometryChange`)
- `FloatingContentHeightKey` (same)
- Dead code: `isAtEnd`, `showTimer`, `onAction`, `updateOpacity`, `isFloatingEnabled`
- Dead `ScriptSegment` properties: `isCue`, `content`
- `CuePromptShortcuts` enum (replaced by direct `onKeyPress`)
- Notification-based menu bar commands (replaced by keyboard modifier)
- Debug print statements

## [0.1.0] - 2025

### Added
- Initial release: teleprompter app for macOS and iOS
- Script management with SwiftData
- Auto-scrolling with adjustable speed
- Timer (count-up and countdown)
- Mirror mode
- Inline cue syntax `[CUE: text]`
- Floating window support (macOS)
- Keyboard shortcuts
