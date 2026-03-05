import SwiftUI
import SwiftData

@main
struct CuePromptApp: App {
    @State private var settings = AppSettings()

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
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Teleprompter") {
                Button("Play/Pause") {
                    NotificationCenter.default.post(name: .teleprompterPlayPause, object: nil)
                }
                .keyboardShortcut(" ", modifiers: [])

                Button("Reset") {
                    NotificationCenter.default.post(name: .teleprompterReset, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Speed Up") {
                    NotificationCenter.default.post(name: .teleprompterSpeedUp, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button("Slow Down") {
                    NotificationCenter.default.post(name: .teleprompterSpeedDown, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)

                Divider()

                Button("Toggle Mirror") {
                    NotificationCenter.default.post(name: .teleprompterMirror, object: nil)
                }
                .keyboardShortcut("m", modifiers: .command)
            }
        }
        #endif

        #if os(iOS)
        // iOS settings view as a scene (for Settings tab in iPadOS)
        #endif
    }
}

// MARK: - Notification names for menu bar commands

extension Notification.Name {
    static let teleprompterPlayPause = Notification.Name("teleprompterPlayPause")
    static let teleprompterReset = Notification.Name("teleprompterReset")
    static let teleprompterSpeedUp = Notification.Name("teleprompterSpeedUp")
    static let teleprompterSpeedDown = Notification.Name("teleprompterSpeedDown")
    static let teleprompterMirror = Notification.Name("teleprompterMirror")
}
