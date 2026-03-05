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
            TeleprompterTopBar(viewModel: viewModel) { dismiss() }
            TeleprompterContentArea(script: script, settings: settings, viewModel: viewModel)
            TransportBar(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.backgroundColor)
        .persistentSystemOverlays(.hidden)
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

// MARK: - Shared Teleprompter Components

struct TeleprompterTopBar: View {
    var viewModel: TeleprompterViewModel
    var onClose: () -> Void

    var body: some View {
        HStack {
            Button("Close") { onClose() }
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
    }
}

struct TeleprompterContentArea: View {
    let script: Script
    var settings: AppSettings
    @Bindable var viewModel: TeleprompterViewModel

    var body: some View {
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
    }
}

// MARK: - Transport Bar (shared between TeleprompterView and FloatingPanelManager)

struct TransportBar: View {
    var viewModel: TeleprompterViewModel
    var controlStyle: TransportControlsView.Style = .compact
    var progressWidth: CGFloat = 80

    var body: some View {
        HStack(spacing: 24) {
            TransportControlsView(viewModel: viewModel, style: controlStyle)

            Spacer()

            GeometryReader { geo in
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geo.size.width * viewModel.progress, height: 3)
            }
            .frame(width: progressWidth, height: 3)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black)
    }
}
