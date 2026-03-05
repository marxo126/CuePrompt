#if os(macOS)
import SwiftUI
import AppKit

@MainActor @Observable
final class FloatingPanelManager {
    static let shared = FloatingPanelManager()

    private var panel: FloatingPanel?
    var isFloating: Bool = false

    private init() {}

    func toggle(settings: AppSettings, script: Script) {
        if isFloating { close() } else { open(settings: settings, script: script) }
    }

    func open(settings: AppSettings, script: Script) {
        close()

        let panel = FloatingPanel(
            contentRect: NSRect(x: 200, y: 200, width: 500, height: 700),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "CuePrompt - \(script.title)"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.alphaValue = settings.floatingWindowOpacity
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let hostingView = NSHostingView(
            rootView: FloatingTeleprompterView(script: script, settings: settings) {
                self.close()
            }
        )
        panel.contentView = hostingView
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        isFloating = true
    }

    func close() {
        panel?.close()
        panel = nil
        isFloating = false
    }

}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct FloatingTeleprompterView: View {
    let script: Script
    var settings: AppSettings
    var onClose: () -> Void
    @State private var viewModel = TeleprompterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
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

            // Transport controls
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
        .background(settings.backgroundColor)
        .onAppear {
            viewModel.applySettings(settings)
        }
        .onDisappear {
            viewModel.pause()
        }
        .focusable()
        .teleprompterKeyboard(viewModel: viewModel, onDismiss: onClose)
    }
}
#endif
