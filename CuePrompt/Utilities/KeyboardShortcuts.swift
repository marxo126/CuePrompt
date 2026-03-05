import SwiftUI

struct TeleprompterKeyboardModifier: ViewModifier {
    var viewModel: TeleprompterViewModel
    var onDismiss: () -> Void
    var onToggleFloat: (() -> Void)?

    func body(content: Content) -> some View {
        content
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
            #if os(macOS)
            .onKeyPress(.init("f")) {
                onToggleFloat?()
                return onToggleFloat != nil ? .handled : .ignored
            }
            #endif
    }
}

extension View {
    func teleprompterKeyboard(
        viewModel: TeleprompterViewModel,
        onDismiss: @escaping () -> Void,
        onToggleFloat: (() -> Void)? = nil
    ) -> some View {
        modifier(TeleprompterKeyboardModifier(
            viewModel: viewModel,
            onDismiss: onDismiss,
            onToggleFloat: onToggleFloat
        ))
    }
}
