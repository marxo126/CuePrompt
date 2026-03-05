import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Observable
final class AppSettings {
    // Font
    var fontSize: Double = 32
    var fontColor: Color = .white
    var backgroundColor: Color = .black
    var lineSpacing: Double = 12
    var horizontalPadding: Double = 24

    // Scroll
    static let speedMin: Double = 0.5
    static let speedMax: Double = 5.0
    static let speedStep: Double = 0.25
    var defaultScrollSpeed: Double = 1.5
    var isMirrored: Bool = false

    // Timer
    var timerMode: TimerMode = .countUp
    var countdownStartSeconds: Int = 300
    var timerWarningThreshold: Int = 30

    // Floating window (macOS)
    var floatingWindowOpacity: Double = 1.0

    // Presentation mode (iOS)
    var presentationMode: PresentationMode = .resizableSheet

    enum TimerMode: String, CaseIterable {
        case countUp = "Count Up"
        case countdown = "Countdown"
    }

    enum PresentationMode: String, CaseIterable {
        case fullScreen = "Full Screen"
        case resizableSheet = "Resizable Sheet"
        case floating = "Floating (PiP)"
    }

    // Persistence via UserDefaults
    private nonisolated(unsafe) static let defaults = UserDefaults.standard

    private enum Key {
        static let fontSize = "cp_fontSize"
        static let scrollSpeed = "cp_scrollSpeed"
        static let mirrored = "cp_mirrored"
        static let lineSpacing = "cp_lineSpacing"
        static let horizontalPadding = "cp_horizontalPadding"
        static let timerMode = "cp_timerMode"
        static let countdownStart = "cp_countdownStart"
        static let timerWarning = "cp_timerWarning"
        static let floatingOpacity = "cp_floatingOpacity"
        static let fontColor = "cp_fontColor"
        static let bgColor = "cp_bgColor"
        static let presentationMode = "cp_presentationMode"
    }

    func save() {
        let d = Self.defaults
        d.set(fontSize, forKey: Key.fontSize)
        d.set(defaultScrollSpeed, forKey: Key.scrollSpeed)
        d.set(isMirrored, forKey: Key.mirrored)
        d.set(lineSpacing, forKey: Key.lineSpacing)
        d.set(horizontalPadding, forKey: Key.horizontalPadding)
        d.set(timerMode.rawValue, forKey: Key.timerMode)
        d.set(countdownStartSeconds, forKey: Key.countdownStart)
        d.set(timerWarningThreshold, forKey: Key.timerWarning)
        d.set(floatingWindowOpacity, forKey: Key.floatingOpacity)
        d.set(fontColor.hexString, forKey: Key.fontColor)
        d.set(backgroundColor.hexString, forKey: Key.bgColor)
        d.set(presentationMode.rawValue, forKey: Key.presentationMode)
    }

    func load() {
        let d = Self.defaults
        if d.object(forKey: Key.fontSize) != nil {
            fontSize = d.double(forKey: Key.fontSize)
        }
        if d.object(forKey: Key.scrollSpeed) != nil {
            defaultScrollSpeed = d.double(forKey: Key.scrollSpeed)
        }
        isMirrored = d.bool(forKey: Key.mirrored)
        if d.object(forKey: Key.lineSpacing) != nil {
            lineSpacing = d.double(forKey: Key.lineSpacing)
        }
        if d.object(forKey: Key.horizontalPadding) != nil {
            horizontalPadding = d.double(forKey: Key.horizontalPadding)
        }
        if let modeStr = d.string(forKey: Key.timerMode),
           let mode = AppSettings.TimerMode(rawValue: modeStr) {
            timerMode = mode
        }
        if d.object(forKey: Key.countdownStart) != nil {
            countdownStartSeconds = d.integer(forKey: Key.countdownStart)
        }
        if d.object(forKey: Key.timerWarning) != nil {
            timerWarningThreshold = d.integer(forKey: Key.timerWarning)
        }
        if d.object(forKey: Key.floatingOpacity) != nil {
            floatingWindowOpacity = d.double(forKey: Key.floatingOpacity)
        }
        if let hex = d.string(forKey: Key.fontColor) {
            fontColor = Color(hex: hex)
        }
        if let hex = d.string(forKey: Key.bgColor) {
            backgroundColor = Color(hex: hex)
        }
        if let modeStr = d.string(forKey: Key.presentationMode),
           let mode = PresentationMode(rawValue: modeStr) {
            presentationMode = mode
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
        let c = PlatformColor(self).sRGBComponents()
        return String(format: "%02X%02X%02X", Int(c.r * 255), Int(c.g * 255), Int(c.b * 255))
    }
}
