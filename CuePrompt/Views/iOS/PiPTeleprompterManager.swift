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
    private var displayLayer = AVSampleBufferDisplayLayer()
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
    private var cachedScriptUpdatedAt: Date?
    private var cachedBgColor: UIColor?
    private var cachedTextColor: UIColor?
    private var cachedFormatDescription: CMFormatDescription?
    private static let colorSpace = CGColorSpaceCreateDeviceRGB()
    private static let renderSize = CGSize(width: 680, height: 400)
    private static let renderWidth = Int(renderSize.width)
    private static let renderHeight = Int(renderSize.height)
    private var pixelBufferPool: CVPixelBufferPool?

    // The inline UIView hosting the display layer (must be in the view hierarchy)
    // Uses a small but non-zero size — PiP requires the layer to be "visible"
    static let inlineSize = CGSize(width: 4, height: 3)

    private(set) var bufferView: UIView = {
        let view = UIView(frame: CGRect(origin: .zero, size: inlineSize))
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        return view
    }()

    private override init() {
        super.init()
        setupDisplayLayer()
        setupPixelBufferPool()
    }

    // MARK: - Setup

    private func setupDisplayLayer() {
        displayLayer.videoGravity = .resizeAspect
        displayLayer.frame = CGRect(origin: .zero, size: Self.inlineSize)
        bufferView.layer.addSublayer(displayLayer)
    }

    private func setupPixelBufferPool() {
        let poolAttrs: [String: Any] = [kCVPixelBufferPoolMinimumBufferCountKey as String: 3]
        let pixelAttrs: [String: Any] = [
            kCVPixelBufferWidthKey as String: Int(Self.renderSize.width),
            kCVPixelBufferHeightKey as String: Int(Self.renderSize.height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
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
                    self.pendingStart = false
                    self.stopRetryTimer()
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

        // Activate audio session (PiP requires this)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
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

    private func invalidateCache() {
        cachedScaledText = nil
        cachedPlainTextAttrs = nil
        cachedBgColor = nil
        cachedTextColor = nil
        cachedScriptUpdatedAt = nil
        cachedFontSize = 0
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
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return }

        // Flip coordinate system for text drawing (CGContext is bottom-up, UIKit is top-down)
        context.translateBy(x: 0, y: CGFloat(Self.renderHeight))
        context.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(context)
        renderIntoContext(script: script, settings: settings, viewModel: viewModel)
        UIGraphicsPopContext()

        guard let sampleBuffer = createSampleBuffer(from: buffer) else { return }

        let sampleRenderer = displayLayer.sampleBufferRenderer
        if sampleRenderer.status == .failed {
            sampleRenderer.flush()
        }
        sampleRenderer.enqueue(sampleBuffer)

        // Stop timer if not playing (render one final frame for current position)
        if !viewModel.isPlaying {
            stopRendering()
        }
    }

    // MARK: - Text Rendering

    private func renderIntoContext(script: Script, settings: AppSettings, viewModel: TeleprompterViewModel) {
        let size = Self.renderSize
        let bgColor = cachedBgColor ?? {
            let c = UIColor(settings.backgroundColor)
            cachedBgColor = c
            return c
        }()

        let margin: CGFloat = 16
        let scrollOffset = viewModel.currentScrollOffset * 0.25
        let textRect = CGRect(
            x: margin,
            y: margin - scrollOffset,
            width: size.width - margin * 2,
            height: size.height * 20
        )

        bgColor.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        if script.attributedString != nil {
            scaledTextForPiP(script: script, settings: settings).draw(in: textRect)
        } else {
            let attrs = plainTextAttrs(settings: settings)
            (script.body as NSString).draw(in: textRect, withAttributes: attrs)
        }

        // Center line indicator
        UIColor.red.withAlphaComponent(0.5).setFill()
        UIRectFill(CGRect(x: 0, y: size.height / 2 - 1, width: size.width, height: 2))
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
            .font: UIFont.systemFont(ofSize: settings.fontSize * 0.6, weight: .medium),
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
           cachedFontColor == currentColor {
            return cached
        }

        guard let attrString = script.attributedString else {
            cachedScaledText = NSAttributedString()
            return cachedScaledText!
        }

        let scaled = TeleprompterContentView.scaledAttributedString(attrString, fontSize: currentFontSize * 0.6, fontColor: currentColor)
        cachedScaledText = scaled
        cachedScriptUpdatedAt = currentUpdatedAt
        cachedFontSize = currentFontSize
        cachedFontColor = currentColor
        return scaled
    }

    // MARK: - CMSampleBuffer

    private func createSampleBuffer(from buffer: CVPixelBuffer) -> CMSampleBuffer? {
        let desc: CMFormatDescription
        if let cached = cachedFormatDescription {
            desc = cached
        } else {
            var formatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &formatDescription)
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
            if viewModel?.isPlaying == true {
                startRendering()
            } else {
                renderFrame()
            }
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
        completionHandler()
    }
}

// MARK: - PiP Inline View (UIViewRepresentable)

struct PiPInlineView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        // Wrap the bufferView in a container to avoid reparenting issues
        let container = UIView(frame: CGRect(origin: .zero, size: PiPTeleprompterManager.inlineSize))
        container.isUserInteractionEnabled = false
        container.clipsToBounds = true
        let bufferView = PiPTeleprompterManager.shared.bufferView
        bufferView.frame = container.bounds
        bufferView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(bufferView)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
