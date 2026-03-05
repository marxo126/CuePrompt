import SwiftUI
import Combine

@Observable
final class TeleprompterViewModel {
    var isPlaying: Bool = false
    var scrollSpeed: Double = 1.5
    var scrollOffset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewHeight: CGFloat = 0
    var isMirrored: Bool = false
    var showTimer: Bool = true

    // Timer
    var elapsedSeconds: Int = 0
    var countdownSeconds: Int = 300
    var timerMode: AppSettings.TimerMode = .countUp

    private var scrollTimer: Timer?
    private var clockTimer: Timer?

    /// Points per second at 1x speed
    private let baseScrollRate: CGFloat = 40.0

    var progress: Double {
        guard contentHeight > viewHeight else { return 0 }
        return min(1.0, Double(scrollOffset / (contentHeight - viewHeight)))
    }

    var isAtEnd: Bool {
        guard contentHeight > viewHeight else { return true }
        return scrollOffset >= contentHeight - viewHeight
    }

    var timerDisplay: String {
        let seconds: Int
        switch timerMode {
        case .countUp:
            seconds = elapsedSeconds
        case .countdown:
            seconds = max(0, countdownSeconds - elapsedSeconds)
        }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var timerColor: Color {
        if timerMode == .countdown {
            let remaining = countdownSeconds - elapsedSeconds
            if remaining <= 0 { return .red }
            if remaining <= 30 { return .orange }
        }
        return .white
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        startScrollTimer()
        startClockTimer()
    }

    func pause() {
        isPlaying = false
        stopScrollTimer()
        stopClockTimer()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func reset() {
        pause()
        scrollOffset = 0
        elapsedSeconds = 0
    }

    func increaseSpeed() {
        scrollSpeed = min(5.0, scrollSpeed + 0.25)
    }

    func decreaseSpeed() {
        scrollSpeed = max(0.5, scrollSpeed - 0.25)
    }

    func toggleMirror() {
        isMirrored.toggle()
    }

    func applySettings(_ settings: AppSettings) {
        scrollSpeed = settings.defaultScrollSpeed
        isMirrored = settings.isMirrored
        timerMode = settings.timerMode
        countdownSeconds = settings.countdownStartSeconds
    }

    // MARK: - Timers

    private func startScrollTimer() {
        stopScrollTimer()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let delta = self.baseScrollRate * CGFloat(self.scrollSpeed) / 60.0
            let newOffset = self.scrollOffset + delta
            if newOffset >= self.contentHeight - self.viewHeight {
                self.scrollOffset = max(0, self.contentHeight - self.viewHeight)
                self.pause()
            } else {
                self.scrollOffset = newOffset
            }
        }
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    private func startClockTimer() {
        stopClockTimer()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopClockTimer() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    deinit {
        stopScrollTimer()
        stopClockTimer()
    }
}
