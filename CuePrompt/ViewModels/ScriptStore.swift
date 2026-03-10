import Foundation
import SwiftData
import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

@Observable
final class ScriptStore {
    var searchText: String = ""

    func filteredScripts(_ scripts: [Script]) -> [Script] {
        if searchText.isEmpty {
            return scripts.sorted { $0.updatedAt > $1.updatedAt }
        }
        return scripts
            .filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.body.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func createScript(context: ModelContext, title: String = "Untitled Script", body: String = "") -> Script {
        let script = Script(title: title, body: body)
        context.insert(script)
        try? context.save()
        return script
    }

    func deleteScript(_ script: Script, context: ModelContext) {
        context.delete(script)
        try? context.save()
    }

    private static let maxImportSize: Int = 10 * 1024 * 1024 // 10 MB

    func importTextFile(url: URL, context: ModelContext) -> Script? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        // Validate file size
        guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = resourceValues.fileSize,
              fileSize <= Self.maxImportSize else {
            return nil
        }

        // Validate file type is plain text
        if let ext = url.pathExtension.isEmpty ? nil : url.pathExtension,
           let utType = UTType(filenameExtension: ext),
           !utType.conforms(to: .plainText) {
            return nil
        }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        let title = url.deletingPathExtension().lastPathComponent
        return createScript(context: context, title: title, body: text)
    }
}
