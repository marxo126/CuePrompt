import SwiftUI
import SwiftData

@main
struct CuePromptApp: App {
    @State private var settings: AppSettings = {
        let s = AppSettings()
        s.load()
        return s
    }()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Script.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 900, height: 600)
        #endif
    }
}

