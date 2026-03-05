import SwiftUI

struct TeleprompterView: View {
    let script: Script
    var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TeleprompterViewModel()

    #if os(macOS)
    @State private var floatingManager = FloatingPanelManager.shared
    #endif

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button("Close") { dismiss() }
                Spacer()
                Text(viewModel.speedLabel)
                    .font(.headline.monospaced())
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Teleprompter content
            ZStack {
                settings.backgroundColor

                TeleprompterContentView(script: script, settings: settings, viewModel: viewModel)

                CenterLineIndicator()

                VStack {
                    HStack {
                        Spacer()
                        TimerView(viewModel: viewModel)
                            .padding()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Transport controls — always visible at bottom
            HStack(spacing: 24) {
                TransportControlsView(viewModel: viewModel, style: .fullscreen)

                Spacer()

                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * viewModel.progress, height: 3)
                }
                .frame(width: 100, height: 3)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
            }
            .padding()
            .background(Color.black)
        }
        .onAppear {
            viewModel.applySettings(settings)
        }
        .onDisappear {
            viewModel.pause()
        }
        .focusable()
        .teleprompterKeyboard(
            viewModel: viewModel,
            onDismiss: { dismiss() },
            onToggleFloat: {
                #if os(macOS)
                floatingManager.toggle(settings: settings, script: script)
                #endif
            }
        )
    }
}
