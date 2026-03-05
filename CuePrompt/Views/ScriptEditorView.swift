import SwiftUI

struct ScriptEditorView: View {
    @Bindable var script: Script
    var settings: AppSettings
    @State private var editingTitle = false
    @State private var formattingCoordinator = FormattingCoordinator()
    #if os(iOS)
    @State private var showTeleprompter = false
    private let pipManager = PiPTeleprompterManager.shared
    #endif

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                if editingTitle {
                    TextField("Title", text: $script.title)
                        .font(.title2.bold())
                        .textFieldStyle(.plain)
                        .onSubmit {
                            editingTitle = false
                            script.updatedAt = Date()
                        }
                } else {
                    Text(script.title)
                        .font(.title2.bold())
                        .onTapGesture {
                            editingTitle = true
                        }
                }
                Spacer()

                #if os(iOS)
                // Mode picker
                Menu {
                    ForEach(AppSettings.PresentationMode.allCases, id: \.self) { mode in
                        Button {
                            settings.presentationMode = mode
                            settings.save()
                        } label: {
                            HStack {
                                Text(mode.rawValue)
                                if settings.presentationMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: modeIcon)
                        .font(.body)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1), in: Circle())
                }
                #endif

                Button {
                    #if os(macOS)
                    FloatingPanelManager.shared.open(settings: settings, script: script)
                    #else
                    presentTeleprompter()
                    #endif
                } label: {
                    Label("Present", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            Divider()

            // Cue syntax help
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Use [CUE: your note] to add inline cues")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(script.body.count) characters")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // Formatting toolbar
            FormattingToolbar(coordinator: formattingCoordinator)

            Divider()

            // Rich text editor
            RichTextEditor(script: script, formattingState: formattingCoordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        }
        #if os(iOS)
        .overlay(alignment: .bottomLeading) {
            // PiP inline view — must be in view hierarchy with non-zero size for AVPictureInPictureController
            PiPInlineView()
                .frame(width: PiPTeleprompterManager.inlineSize.width, height: PiPTeleprompterManager.inlineSize.height)
                .allowsHitTesting(false)
        }
        #endif
        .navigationTitle(script.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTeleprompter) {
            let isResizable = settings.presentationMode == .resizableSheet
            TeleprompterView(script: script, settings: settings)
                .presentationDetents(isResizable ? [.fraction(0.3), .medium, .large] : [.large])
                .presentationDragIndicator(isResizable ? .visible : .hidden)
                .presentationBackgroundInteraction(isResizable ? .enabled : .disabled)
                .presentationCornerRadius(20)
                .interactiveDismissDisabled(isResizable)
        }
        #endif
    }

    // MARK: - iOS Helpers

    #if os(iOS)
    private var modeIcon: String {
        switch settings.presentationMode {
        case .fullScreen: return "arrow.up.left.and.arrow.down.right"
        case .resizableSheet: return "rectangle.bottomhalf.inset.filled"
        case .floating: return "pip"
        }
    }

    private func presentTeleprompter() {
        switch settings.presentationMode {
        case .fullScreen, .resizableSheet:
            showTeleprompter = true
        case .floating:
            let vm = TeleprompterViewModel()
            pipManager.start(script: script, settings: settings, viewModel: vm)
        }
    }
    #endif
}
