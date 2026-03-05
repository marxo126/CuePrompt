import SwiftUI

@Observable
final class AppSettings {
    // Font
    var fontSize: Double = 32
    var fontColor: Color = .white
    var backgroundColor: Color = .black
    var lineSpacing: Double = 12
    var horizontalPadding: Double = 24

    // Scroll
    var defaultScrollSpeed: Double = 1.5
    var isMirrored: Bool = false

    // Timer
    var timerMode: TimerMode = .countUp
    var countdownStartSeconds: Int = 300
    var timerWarningThreshold: Int = 30

    // Floating window (macOS)
    var floatingWindowOpacity: Double = 1.0
    var isFloatingEnabled: Bool = false

    enum TimerMode: String, CaseIterable {
        case countUp = "Count Up"
        case countdown = "Countdown"
    }

    // Persistence via UserDefaults
    private static let defaults = UserDefaults.standard

    func save() {
        let d = Self.defaults
        d.set(fontSize, forKey: "cp_fontSize")
        d.set(defaultScrollSpeed, forKey: "cp_scrollSpeed")
        d.set(isMirrored, forKey: "cp_mirrored")
        d.set(lineSpacing, forKey: "cp_lineSpacing")
        d.set(horizontalPadding, forKey: "cp_horizontalPadding")
        d.set(timerMode.rawValue, forKey: "cp_timerMode")
        d.set(countdownStartSeconds, forKey: "cp_countdownStart")
        d.set(timerWarningThreshold, forKey: "cp_timerWarning")
        d.set(floatingWindowOpacity, forKey: "cp_floatingOpacity")

        // Colors stored as hex
        d.set(fontColor.hexString, forKey: "cp_fontColor")
        d.set(backgroundColor.hexString, forKey: "cp_bgColor")
    }

    func load() {
        let d = Self.defaults
        if d.object(forKey: "cp_fontSize") != nil {
            fontSize = d.double(forKey: "cp_fontSize")
        }
        if d.object(forKey: "cp_scrollSpeed") != nil {
            defaultScrollSpeed = d.double(forKey: "cp_scrollSpeed")
        }
        isMirrored = d.bool(forKey: "cp_mirrored")
        if d.object(forKey: "cp_lineSpacing") != nil {
            lineSpacing = d.double(forKey: "cp_lineSpacing")
        }
        if d.object(forKey: "cp_horizontalPadding") != nil {
            horizontalPadding = d.double(forKey: "cp_horizontalPadding")
        }
        if let modeStr = d.string(forKey: "cp_timerMode"),
           let mode = AppSettings.TimerMode(rawValue: modeStr) {
            timerMode = mode
        }
        if d.object(forKey: "cp_countdownStart") != nil {
            countdownStartSeconds = d.integer(forKey: "cp_countdownStart")
        }
        if d.object(forKey: "cp_timerWarning") != nil {
            timerWarningThreshold = d.integer(forKey: "cp_timerWarning")
        }
        if d.object(forKey: "cp_floatingOpacity") != nil {
            floatingWindowOpacity = d.double(forKey: "cp_floatingOpacity")
        }
        if let hex = d.string(forKey: "cp_fontColor") {
            fontColor = Color(hex: hex)
        }
        if let hex = d.string(forKey: "cp_bgColor") {
            backgroundColor = Color(hex: hex)
        }
    }
}

// MARK: - Color Hex Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hexString: String {
        guard let components = cgColor?.components, components.count >= 3 else {
            return "FFFFFF"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
