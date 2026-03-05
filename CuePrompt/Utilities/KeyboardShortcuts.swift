import SwiftUI

/// Keyboard shortcut definitions for the CuePrompt app.
/// These are used via SwiftUI's `.keyboardShortcut()` modifier and `onKeyPress` in views.
enum CuePromptShortcuts {
    // Teleprompter controls
    static let playPause = KeyEquivalent(" ")
    static let speedUp = KeyEquivalent.upArrow
    static let speedDown = KeyEquivalent.downArrow
    static let reset = KeyEquivalent("r")
    static let mirror = KeyEquivalent("m")
    static let exitTeleprompter = KeyEquivalent.escape

    #if os(macOS)
    static let toggleFloating = KeyEquivalent("f")
    #endif
}

/// A view modifier that adds teleprompter keyboard shortcuts on iOS via .onKeyPress
/// (iPad with external keyboard support).
struct TeleprompterKeyboardModifier: ViewModifier {
    var viewModel: TeleprompterViewModel
    var onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
        #if os(iOS)
            .onKeyPress(.space) {
                viewModel.togglePlayPause()
                return .handled
            }
            .onKeyPress(.upArrow) {
                viewModel.increaseSpeed()
                return .handled
            }
            .onKeyPress(.downArrow) {
                viewModel.decreaseSpeed()
                return .handled
            }
            .onKeyPress(.init("r")) {
                viewModel.reset()
                return .handled
            }
            .onKeyPress(.init("m")) {
                viewModel.toggleMirror()
                return .handled
            }
            .onKeyPress(.escape) {
                onDismiss()
                return .handled
            }
        #endif
    }
}

extension View {
    func teleprompterKeyboard(viewModel: TeleprompterViewModel, onDismiss: @escaping () -> Void) -> some View {
        modifier(TeleprompterKeyboardModifier(viewModel: viewModel, onDismiss: onDismiss))
    }
}
