import SwiftUI

struct TeleprompterView: View {
    let script: Script
    var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TeleprompterViewModel()
    @State private var showControls = true
    @State private var controlsHideTask: Task<Void, Never>?

    #if os(macOS)
    @State private var floatingManager = FloatingPanelManager.shared
    #endif

    var body: some View {
        ZStack {
            settings.backgroundColor
                .ignoresSafeArea()

            // Scrolling content
            GeometryReader { outerGeo in
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Top spacer so text starts from center
                            Spacer()
                                .frame(height: outerGeo.size.height / 2)

                            segmentsView
                                .padding(.horizontal, settings.horizontalPadding)

                            // Bottom spacer
                            Spacer()
                                .frame(height: outerGeo.size.height / 2)
                        }
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear.preference(
                                    key: ContentHeightKey.self,
                                    value: contentGeo.size.height
                                )
                            }
                        )
                        .offset(y: -viewModel.scrollOffset)
                    }
                    .scrollDisabled(viewModel.isPlaying)
                    .onPreferenceChange(ContentHeightKey.self) { height in
                        viewModel.contentHeight = height
                    }
                    .onAppear {
                        viewModel.viewHeight = outerGeo.size.height
                    }
                    .onChange(of: outerGeo.size.height) { _, newHeight in
                        viewModel.viewHeight = newHeight
                    }
                }
            }
            .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)

            // Center line indicator
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(height: 2)
                Spacer()
            }
            .allowsHitTesting(false)

            // Timer overlay
            if viewModel.showTimer {
                VStack {
                    HStack {
                        Spacer()
                        TimerView(viewModel: viewModel)
                            .padding()
                    }
                    Spacer()
                }
            }

            // Controls overlay
            if showControls {
                controlsOverlay
            }
        }
        .onAppear {
            viewModel.applySettings(settings)
            scheduleHideControls()
        }
        .onTapGesture {
            showControls.toggle()
            if showControls {
                scheduleHideControls()
            }
        }
        #if os(macOS)
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
            dismiss()
            return .handled
        }
        .onKeyPress(.init("f")) {
            floatingManager.toggle(settings: settings, script: script)
            return .handled
        }
        #endif
    }

    // MARK: - Segments rendering

    private var segmentsView: some View {
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
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(String(format: "%.1fx", viewModel.scrollSpeed))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding()

            Spacer()

            // Bottom controls
            HStack(spacing: 30) {
                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }

                Button {
                    viewModel.decreaseSpeed()
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                }

                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                }

                Button {
                    viewModel.increaseSpeed()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                }

                Button {
                    viewModel.toggleMirror()
                } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        .font(.title2)
                }
            }
            .foregroundStyle(.white)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 30)

            // Progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geo.size.width * viewModel.progress, height: 3)
            }
            .frame(height: 3)
        }
    }

    private func scheduleHideControls() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                withAnimation { showControls = false }
            }
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
