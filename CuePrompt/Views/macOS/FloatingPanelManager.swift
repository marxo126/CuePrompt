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
            TeleprompterTopBar(viewModel: viewModel, onClose: onClose)
            TeleprompterContentArea(script: script, settings: settings, viewModel: viewModel)
            TransportBar(viewModel: viewModel, controlStyle: .fullscreen, progressWidth: 100)
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
