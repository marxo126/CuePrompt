import SwiftUI

struct ScriptEditorView: View {
    @Bindable var script: Script
    var settings: AppSettings
    @State private var editingTitle = false
    @State private var formattingCoordinator = FormattingCoordinator()
    #if os(iOS)
    @State private var showTeleprompter = false
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
                Button {
                    #if os(macOS)
                    FloatingPanelManager.shared.open(settings: settings, script: script)
                    #else
                    showTeleprompter = true
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
        }
        .navigationTitle(script.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showTeleprompter) {
            TeleprompterView(script: script, settings: settings)
        }
        #endif
    }
}
