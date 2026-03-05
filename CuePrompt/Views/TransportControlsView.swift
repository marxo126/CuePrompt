import SwiftUI

struct TransportControlsView: View {
    var viewModel: TeleprompterViewModel
    var style: Style = .fullscreen
    enum Style {
        case fullscreen
        case compact
    }

    var body: some View {
        HStack(spacing: style == .fullscreen ? 30 : 20) {
            transportButton(icon: "backward.end.fill") {
                viewModel.reset()
            }

            transportButton(icon: "minus.circle") {
                viewModel.decreaseSpeed()
            }

            transportButton(icon: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill", isMain: true) {
                viewModel.togglePlayPause()
            }

            transportButton(icon: "plus.circle") {
                viewModel.increaseSpeed()
            }

            transportButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                viewModel.toggleMirror()
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func transportButton(icon: String, isMain: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(isMain
                    ? (style == .fullscreen ? .system(size: 50) : .title)
                    : (style == .fullscreen ? .title2 : .body))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
