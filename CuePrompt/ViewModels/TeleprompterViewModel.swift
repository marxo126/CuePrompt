import SwiftUI

@MainActor @Observable
final class TeleprompterViewModel {
    var isPlaying: Bool = false
    var scrollSpeed: Double = 1.5
    var isMirrored: Bool = false

    // Scroll state driven by ScrollPosition API
    var scrollPosition = ScrollPosition(edge: .top)
    var currentScrollOffset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewHeight: CGFloat = 0

    // Timer
    var elapsedSeconds: Int = 0
    var countdownSeconds: Int = 300
    var timerMode: AppSettings.TimerMode = .countUp
    var timerWarningThreshold: Int = 30

    @ObservationIgnored nonisolated(unsafe) private var scrollTimer: Timer?
    @ObservationIgnored nonisolated(unsafe) private var clockTimer: Timer?

    /// Points per second at 1x speed
    private let baseScrollRate: CGFloat = 40.0

    var progress: Double {
        guard contentHeight > viewHeight else { return 0 }
        return min(1.0, Double(currentScrollOffset / (contentHeight - viewHeight)))
    }

    var speedLabel: String {
        String(format: "%.1fx", scrollSpeed)
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
            if remaining <= timerWarningThreshold { return .orange }
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
        currentScrollOffset = 0
        elapsedSeconds = 0
        scrollPosition.scrollTo(edge: .top)
    }

    func increaseSpeed() {
        scrollSpeed = min(AppSettings.speedMax, scrollSpeed + AppSettings.speedStep)
    }

    func decreaseSpeed() {
        scrollSpeed = max(AppSettings.speedMin, scrollSpeed - AppSettings.speedStep)
    }

    func toggleMirror() {
        isMirrored.toggle()
    }

    func applySettings(_ settings: AppSettings) {
        scrollSpeed = settings.defaultScrollSpeed
        isMirrored = settings.isMirrored
        timerMode = settings.timerMode
        countdownSeconds = settings.countdownStartSeconds
        timerWarningThreshold = settings.timerWarningThreshold
    }

    /// Called by onScrollGeometryChange to sync manual scroll position.
    /// Skipped during playback to avoid feedback loop with the scroll timer.
    func updateScrollOffset(_ offset: CGFloat) {
        guard !isPlaying else { return }
        currentScrollOffset = offset
    }

    // MARK: - Timers

    private func startScrollTimer() {
        stopScrollTimer()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let delta = self.baseScrollRate * CGFloat(self.scrollSpeed) / 60.0
                let maxOffset = max(0, self.contentHeight - self.viewHeight)
                let newOffset = self.currentScrollOffset + delta
                if newOffset >= maxOffset {
                    self.currentScrollOffset = maxOffset
                    self.scrollPosition.scrollTo(y: maxOffset)
                    self.pause()
                } else {
                    self.currentScrollOffset = newOffset
                    self.scrollPosition.scrollTo(y: newOffset)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        scrollTimer = timer
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    private func startClockTimer() {
        stopClockTimer()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.elapsedSeconds += 1
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    private func stopClockTimer() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    deinit {
        scrollTimer?.invalidate()
        clockTimer?.invalidate()
    }
}
