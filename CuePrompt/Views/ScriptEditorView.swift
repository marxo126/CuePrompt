import SwiftUI

struct ScriptEditorView: View {
    @Bindable var script: Script
    var settings: AppSettings
    @State private var showTeleprompter = false
    @State private var editingTitle = false

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
                    showTeleprompter = true
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

            // Editor
            TextEditor(text: $script.body)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .padding(8)
                .onChange(of: script.body) {
                    script.updatedAt = Date()
                }
        }
        .navigationTitle(script.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showTeleprompter) {
            TeleprompterView(script: script, settings: settings)
        }
        #else
        .sheet(isPresented: $showTeleprompter) {
            TeleprompterView(script: script, settings: settings)
                .frame(minWidth: 600, minHeight: 500)
        }
        #endif
    }
}
