#if os(macOS)
import SwiftUI
import AppKit

/// Manages a floating NSPanel window for the teleprompter on macOS.
@Observable
final class FloatingPanelManager {
    static let shared = FloatingPanelManager()

    private var panel: FloatingPanel?
    var isFloating: Bool = false

    private init() {}

    func toggle(settings: AppSettings, script: Script) {
        if isFloating {
            close()
        } else {
            open(settings: settings, script: script)
        }
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

    func updateOpacity(_ opacity: Double) {
        panel?.alphaValue = opacity
    }
}

/// Custom NSPanel subclass for floating behavior.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A simplified teleprompter view for the floating panel.
struct FloatingTeleprompterView: View {
    let script: Script
    var settings: AppSettings
    var onClose: () -> Void
    @State private var viewModel = TeleprompterViewModel()

    var body: some View {
        ZStack {
            settings.backgroundColor
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: geo.size.height / 2)

                        VStack(alignment: .leading, spacing: settings.lineSpacing) {
                            ForEach(script.segments) { segment in
                                switch segment {
                                case .text(let text):
                                    Text(text)
                                        .font(.system(size: settings.fontSize, weight: .medium))
                                        .foregroundStyle(settings.fontColor)
                                        .lineSpacing(settings.lineSpacing)
                                case .cue(let cueText):
                                    CueNoteView(text: cueText, fontSize: settings.fontSize * 0.65)
                                }
                            }
                        }
                        .padding(.horizontal, settings.horizontalPadding)

                        Spacer().frame(height: geo.size.height / 2)
                    }
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.preference(key: FloatingContentHeightKey.self, value: contentGeo.size.height)
                        }
                    )
                    .offset(y: -viewModel.scrollOffset)
                }
                .scrollDisabled(viewModel.isPlaying)
                .onPreferenceChange(FloatingContentHeightKey.self) { viewModel.contentHeight = $0 }
                .onAppear {
                    viewModel.viewHeight = geo.size.height
                    viewModel.applySettings(settings)
                }
                .onChange(of: geo.size.height) { _, h in viewModel.viewHeight = h }
            }
            .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)

            // Center indicator
            VStack {
                Spacer()
                Rectangle().fill(Color.red.opacity(0.5)).frame(height: 2)
                Spacer()
            }
            .allowsHitTesting(false)

            // Minimal controls at bottom
            VStack {
                // Timer
                HStack {
                    Spacer()
                    TimerView(viewModel: viewModel).padding(8)
                }
                Spacer()
                HStack(spacing: 20) {
                    Button { viewModel.reset() } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    Button { viewModel.decreaseSpeed() } label: {
                        Image(systemName: "minus.circle")
                    }
                    Button { viewModel.togglePlayPause() } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                    }
                    Button { viewModel.increaseSpeed() } label: {
                        Image(systemName: "plus.circle")
                    }
                    Button { viewModel.toggleMirror() } label: {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                    Spacer()
                    Text(String(format: "%.1fx", viewModel.scrollSpeed))
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.7))
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle")
                    }
                }
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.5))
            }
        }
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
            onClose()
            return .handled
        }
    }
}

private struct FloatingContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
#endif
