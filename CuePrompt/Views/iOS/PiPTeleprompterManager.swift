#if os(iOS)
import UIKit
import AVKit
import AVFoundation
import SwiftUI
import CoreMedia

@MainActor @Observable
final class PiPTeleprompterManager: NSObject {
    static let shared = PiPTeleprompterManager()

    var isPiPActive = false

    private var pipController: AVPictureInPictureController?
    private(set) var displayLayer = AVSampleBufferDisplayLayer()
    @ObservationIgnored nonisolated(unsafe) private var renderTimer: Timer?
    @ObservationIgnored nonisolated(unsafe) private var pipPossibleRetryTimer: Timer?
    private var pendingStart = false
    private var retryCount = 0
    private static let maxRetries = 20 // 2 seconds at 0.1s intervals

    // Rendering state
    private(set) var script: Script?
    private(set) var settings: AppSettings?
    private(set) var viewModel: TeleprompterViewModel?

    // Cached rendering resources
    private var cachedScaledText: NSAttributedString?
    private var cachedPlainTextAttrs: [NSAttributedString.Key: Any]?
    private var cachedFontSize: Double = 0
    private var cachedFontColor: Color = .white
    private var cachedPipTextScale: Double = 0
    private var cachedScriptUpdatedAt: Date?
    private var cachedBgColor: UIColor?
    private var cachedTextColor: UIColor?
    private static let colorSpace = CGColorSpaceCreateDeviceRGB()
    private static let renderSize = CGSize(width: 680, height: 400)
    private static let renderWidth = Int(renderSize.width)
    private static let renderHeight = Int(renderSize.height)
    private static let margin: CGFloat = 16
    private var speedOverlayOpacity: CGFloat = 0
    private var cachedSpeedLabel: String?
    private var cachedFormatDescription: CMFormatDescription?
    private static let overlayFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    private static let centerLineColor = UIColor.red.withAlphaComponent(0.5)
    private var pixelBufferPool: CVPixelBufferPool?

    // The display layer must be in the view hierarchy for PiP to work.
    // PiPInlineView adds it to a fresh UIView via CALayer (not UIView reparenting).
    static let inlineSize = CGSize(width: 4, height: 3)

    private override init() {
        super.init()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.frame = CGRect(origin: .zero, size: Self.inlineSize)
        setupPixelBufferPool()
    }

    private func setupPixelBufferPool() {
        let poolAttrs: [String: Any] = [kCVPixelBufferPoolMinimumBufferCountKey as String: 3]
        let pixelAttrs: [String: Any] = [
            kCVPixelBufferWidthKey as String: Self.renderWidth,
            kCVPixelBufferHeightKey as String: Self.renderHeight,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttrs as CFDictionary, pixelAttrs as CFDictionary, &pixelBufferPool)
    }

    /// Creates the PiP controller. Must be called after the displayLayer has content.
    private func ensurePiPController() {
        guard pipController == nil else { return }

        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )

        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
    }

    /// Polls `isPictureInPicturePossible` until true, then starts PiP.
    private func startPiPWhenReady() {
        stopRetryTimer()
        retryCount = 0

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.pendingStart else {
                    self?.stopRetryTimer()
                    return
                }
                self.retryCount += 1

                if let controller = self.pipController, controller.isPictureInPicturePossible {
                    self.pendingStart = false
                    self.stopRetryTimer()
                    controller.startPictureInPicture()
                } else if self.retryCount >= Self.maxRetries {
                    print("[PiP] Gave up waiting for PiP to become possible")
                    self.cleanup()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pipPossibleRetryTimer = timer
    }

    private func stopRetryTimer() {
        pipPossibleRetryTimer?.invalidate()
        pipPossibleRetryTimer = nil
    }

    // MARK: - Public

    func start(script: Script, settings: AppSettings, viewModel: TeleprompterViewModel) {
        self.script = script
        self.settings = settings
        self.viewModel = viewModel
        viewModel.applySettings(settings)
        invalidateCache()

        // Set virtual content dimensions so the scroll timer doesn't immediately auto-pause
        let textHeight = measureTextHeight(script: script, settings: settings)
        viewModel.viewHeight = Self.renderSize.height
        viewModel.contentHeight = textHeight + Self.renderSize.height // add padding like the real teleprompter

        // PiP viewport is much smaller — halve the scroll speed so text doesn't fly by
        viewModel.scrollSpeed = max(AppSettings.speedMin, settings.defaultScrollSpeed * 0.5)

        // Activate audio session (PiP requires this)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("[PiP] Audio session error: \(error)")
        }

        // Start continuous rendering — PiP requires active frame delivery
        startRendering()

        // Create controller after first frame is enqueued
        ensurePiPController()

        // Try to start PiP, or poll until it becomes possible
        if let controller = pipController, controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
        } else {
            print("[PiP] Not yet possible, polling...")
            pendingStart = true
            startPiPWhenReady()
        }
    }

    func stop() {
        pendingStart = false
        pipController?.stopPictureInPicture()
        cleanup()
    }

    private func cleanup() {
        stopRendering()
        stopRetryTimer()
        pendingStart = false
        viewModel?.pause()
        viewModel = nil
        script = nil
        settings = nil
        isPiPActive = false
        invalidateCache()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func showSpeedOverlay() {
        speedOverlayOpacity = 1.0
        cachedSpeedLabel = viewModel?.speedLabel
    }

    private func invalidateCache() {
        cachedScaledText = nil
        cachedPlainTextAttrs = nil
        cachedBgColor = nil
        cachedTextColor = nil
        cachedScriptUpdatedAt = nil
        cachedFontSize = 0
        cachedPipTextScale = 0
        cachedSpeedLabel = nil
    }

    // MARK: - Text Measurement

    private func measureTextHeight(script: Script, settings: AppSettings) -> CGFloat {
        let textWidth = Self.renderSize.width - Self.margin * 2
        let constraintSize = CGSize(width: textWidth, height: .greatestFiniteMagnitude)

        if script.attributedString != nil {
            let scaled = scaledTextForPiP(script: script, settings: settings)
            let rect = scaled.boundingRect(with: constraintSize, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            return rect.height
        } else {
            let attrs = plainTextAttrs(settings: settings)
            let rect = (script.body as NSString).boundingRect(with: constraintSize, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
            return rect.height
        }
    }

    // MARK: - Rendering

    private func startRendering() {
        stopRendering()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.renderFrame()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        renderTimer = timer
    }

    private func stopRendering() {
        renderTimer?.invalidate()
        renderTimer = nil
    }

    private func renderFrame() {
        guard let script, let settings, let viewModel else { return }
        guard let pool = pixelBufferPool else { return }

        // Drive speed overlay fade from the render loop
        if speedOverlayOpacity > 0 {
            speedOverlayOpacity -= 1.0 / 30.0
            if speedOverlayOpacity < 0 { speedOverlayOpacity = 0 }
        }

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer else { return }

        // Draw directly into pixel buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Self.renderWidth, height: Self.renderHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: Self.colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return }

        // Flip coordinate system for text drawing (CGContext is bottom-up, UIKit is top-down)
        context.translateBy(x: 0, y: CGFloat(Self.renderHeight))
        context.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(context)
        renderIntoContext(script: script, settings: settings, viewModel: viewModel)
        UIGraphicsPopContext()

        guard let sampleBuffer = createSampleBuffer(from: buffer) else { return }

        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
    }

    // MARK: - Text Rendering

    private func renderIntoContext(script: Script, settings: AppSettings, viewModel: TeleprompterViewModel) {
        let size = Self.renderSize
        let bgColor = cachedBgColor ?? {
            let c = UIColor(settings.backgroundColor)
            cachedBgColor = c
            return c
        }()

        let scrollOffset = viewModel.currentScrollOffset
        let textHeight = max(size.height, viewModel.contentHeight)
        let textRect = CGRect(
            x: Self.margin,
            y: Self.margin - scrollOffset,
            width: size.width - Self.margin * 2,
            height: textHeight
        )

        bgColor.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        // Clip to visible area to reduce text layout work
        UIRectClip(CGRect(origin: .zero, size: size))

        if script.attributedString != nil {
            scaledTextForPiP(script: script, settings: settings).draw(in: textRect)
        } else {
            let attrs = plainTextAttrs(settings: settings)
            (script.body as NSString).draw(in: textRect, withAttributes: attrs)
        }

        // Center line indicator
        Self.centerLineColor.setFill()
        UIRectFill(CGRect(x: 0, y: size.height / 2 - 1, width: size.width, height: 2))

        // Speed overlay (shown briefly after skip-button speed change)
        if speedOverlayOpacity > 0, let label = cachedSpeedLabel {
            let font = Self.overlayFont
            let textSize = (label as NSString).size(withAttributes: [.font: font])
            let pillPadding: CGFloat = 8
            let pillRect = CGRect(
                x: size.width - textSize.width - pillPadding * 2 - 8,
                y: 8,
                width: textSize.width + pillPadding * 2,
                height: textSize.height + pillPadding
            )
            UIColor.black.withAlphaComponent(0.6 * speedOverlayOpacity).setFill()
            UIBezierPath(roundedRect: pillRect, cornerRadius: pillRect.height / 2).fill()
            let textOrigin = CGPoint(x: pillRect.midX - textSize.width / 2, y: pillRect.midY - textSize.height / 2)
            (label as NSString).draw(at: textOrigin, withAttributes: [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(speedOverlayOpacity),
            ])
        }
    }

    private func plainTextAttrs(settings: AppSettings) -> [NSAttributedString.Key: Any] {
        if let cached = cachedPlainTextAttrs { return cached }

        let textColor = cachedTextColor ?? {
            let c = UIColor(settings.fontColor)
            cachedTextColor = c
            return c
        }()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = settings.lineSpacing * 0.5

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: settings.fontSize * settings.pipTextScale, weight: .medium),
            .foregroundColor: textColor,
            .paragraphStyle: style,
        ]
        cachedPlainTextAttrs = attrs
        return attrs
    }

    private func scaledTextForPiP(script: Script, settings: AppSettings) -> NSAttributedString {
        let currentUpdatedAt = script.updatedAt
        let currentFontSize = settings.fontSize
        let currentColor = settings.fontColor

        if let cached = cachedScaledText,
           cachedScriptUpdatedAt == currentUpdatedAt,
           cachedFontSize == currentFontSize,
           cachedFontColor == currentColor,
           cachedPipTextScale == settings.pipTextScale {
            return cached
        }

        guard let attrString = script.attributedString else {
            cachedScaledText = NSAttributedString()
            return cachedScaledText!
        }

        let scaled = TeleprompterContentView.scaledAttributedString(attrString, fontSize: currentFontSize * settings.pipTextScale, fontColor: currentColor)
        cachedScaledText = scaled
        cachedScriptUpdatedAt = currentUpdatedAt
        cachedFontSize = currentFontSize
        cachedFontColor = currentColor
        cachedPipTextScale = settings.pipTextScale
        return scaled
    }

    // MARK: - CMSampleBuffer

    private func createSampleBuffer(from buffer: CVPixelBuffer) -> CMSampleBuffer? {
        let desc: CMFormatDescription
        if let cached = cachedFormatDescription {
            desc = cached
        } else {
            var formatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: buffer,
                formatDescriptionOut: &formatDescription
            )
            guard let created = formatDescription else { return nil }
            cachedFormatDescription = created
            desc = created
        }

        let now = CMTime(value: Int64(CACurrentMediaTime() * 1000), timescale: 1000)
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: now,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: desc,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPTeleprompterManager: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            print("[PiP] Will start")
            isPiPActive = true
            viewModel?.play()
            startRendering()
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            print("[PiP] Did stop")
            cleanup()
        }
    }

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        MainActor.assumeIsolated {
            print("[PiP] Failed to start: \(error)")
            cleanup()
        }
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PiPTeleprompterManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
        MainActor.assumeIsolated {
            if playing {
                viewModel?.play()
                startRendering()
            } else {
                viewModel?.pause()
                stopRendering()
                renderFrame() // one final frame at current position
            }
        }
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: CMTime(value: 3600, timescale: 1))
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        MainActor.assumeIsolated {
            !(viewModel?.isPlaying ?? true)
        }
    }

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        let seconds = CMTimeGetSeconds(skipInterval)
        MainActor.assumeIsolated {
            guard let viewModel else { return }
            // Repurpose skip buttons for speed control
            if seconds > 0 {
                viewModel.increaseSpeed()
            } else {
                viewModel.decreaseSpeed()
            }
            showSpeedOverlay()
            renderFrame()
        }
        completionHandler()
    }
}

// MARK: - PiP Inline View (UIViewRepresentable)

struct PiPInlineView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(origin: .zero, size: PiPTeleprompterManager.inlineSize))
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        // Add the display layer directly — no UIView reparenting
        let layer = PiPTeleprompterManager.shared.displayLayer
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
