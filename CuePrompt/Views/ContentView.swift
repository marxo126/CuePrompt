import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store = ScriptStore()
    @State private var settings = AppSettings()
    @State private var selectedScript: Script?
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            ScriptListView(
                store: store,
                selectedScript: $selectedScript
            )
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            #endif
        } detail: {
            if let script = selectedScript {
                ScriptEditorView(script: script, settings: settings)
            } else {
                ContentUnavailableView(
                    "No Script Selected",
                    systemImage: "doc.text",
                    description: Text("Select a script from the sidebar or create a new one.")
                )
            }
        }
        .onAppear {
            settings.load()
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
                .frame(minWidth: 400, minHeight: 450)
        }
        #endif
    }
}
