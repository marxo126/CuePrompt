import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ScriptListView: View {
    @Bindable var store: ScriptStore
    @Binding var selectedScript: Script?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]
    @State private var showImporter = false

    var body: some View {
        List(selection: $selectedScript) {
            ForEach(store.filteredScripts(scripts)) { script in
                NavigationLink(value: script) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(script.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(script.body.prefix(80).replacingOccurrences(of: "\n", with: " "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(script.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        if selectedScript?.id == script.id {
                            selectedScript = nil
                        }
                        store.deleteScript(script, context: modelContext)
                    }
                }
            }
            .onDelete { indexSet in
                let filtered = store.filteredScripts(scripts)
                for index in indexSet {
                    let script = filtered[index]
                    if selectedScript?.id == script.id {
                        selectedScript = nil
                    }
                    store.deleteScript(script, context: modelContext)
                }
            }
        }
        .searchable(text: $store.searchText, prompt: "Search scripts")
        .navigationTitle("Scripts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        let script = store.createScript(context: modelContext)
                        selectedScript = script
                    } label: {
                        Label("New Script", systemImage: "plus")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Text File", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if let script = store.importTextFile(url: url, context: modelContext) {
                    selectedScript = script
                }
            }
        }
    }
}
