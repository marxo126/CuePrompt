import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct TeleprompterContentView: View {
    let script: Script
    var settings: AppSettings
    @Bindable var viewModel: TeleprompterViewModel

    // Cached scaled attributed string — only recomputed when content/settings change, not on scroll
    @State private var scaledText: AttributedString?

    var body: some View {
        GeometryReader { outerGeo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(height: outerGeo.size.height / 2)

                    if script.attributedString != nil {
                        richTextContent
                            .padding(.horizontal, settings.horizontalPadding)
                    } else {
                        VStack(alignment: .leading, spacing: settings.lineSpacing) {
                            ForEach(script.segments) { segment in
                                switch segment {
                                case .text(let text, _):
                                    Text(text)
                                        .font(.system(size: settings.fontSize, weight: .medium))
                                        .foregroundStyle(settings.fontColor)
                                        .lineSpacing(settings.lineSpacing)
                                case .cue(let cueText, _):
                                    CueNoteView(text: cueText, fontSize: settings.fontSize * 0.65)
                                }
                            }
                        }
                        .padding(.horizontal, settings.horizontalPadding)
                    }

                    Spacer()
                        .frame(height: outerGeo.size.height / 2)
                }
            }
            .scrollPosition($viewModel.scrollPosition)
            .scrollDisabled(viewModel.isPlaying)
            .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
                ScrollMetrics(offset: geo.contentOffset.y, contentHeight: geo.contentSize.height)
            } action: { _, newValue in
                viewModel.updateScrollOffset(newValue.offset)
                viewModel.contentHeight = newValue.contentHeight
            }
            .onAppear {
                viewModel.viewHeight = outerGeo.size.height
                rebuildScaledText()
            }
            .onChange(of: outerGeo.size.height) { _, newHeight in
                viewModel.viewHeight = newHeight
            }
            .onChange(of: script.attributedBody) { _, _ in rebuildScaledText() }
            .onChange(of: settings.fontSize) { _, _ in rebuildScaledText() }
            .onChange(of: settings.fontColor) { _, _ in rebuildScaledText() }
        }
        .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
    }

    @ViewBuilder
    private var richTextContent: some View {
        if let scaled = scaledText {
            Text(scaled)
                .lineSpacing(settings.lineSpacing)
        }
    }

    private func rebuildScaledText() {
        guard let attrString = script.attributedString else {
            scaledText = nil
            return
        }
        let ns = Self.scaledAttributedString(attrString, fontSize: settings.fontSize, fontColor: settings.fontColor)
        scaledText = AttributedString(ns)
    }

    static func scaledAttributedString(_ attrString: NSAttributedString, fontSize: Double, fontColor: Color) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attrString)
        let scaleFactor = fontSize / RichTextCoordinatorCore.defaultFontSize
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let font = (value as? PlatformFont) ?? .defaultFont(ofSize: RichTextCoordinatorCore.defaultFontSize)
            mutable.addAttribute(.font, value: font.withPointSize(font.pointSize * scaleFactor), range: range)
        }

        let teleColor = PlatformColor(fontColor)
        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if let color = value as? PlatformColor, !isDefaultLabelColor(color) {
                return
            }
            mutable.addAttribute(.foregroundColor, value: teleColor, range: range)
        }

        mutable.removeAttribute(.backgroundColor, range: fullRange)
        return mutable
    }

    private static let defaultLabelComponents = PlatformColor.defaultLabelColor.sRGBComponents()

    private static func isDefaultLabelColor(_ color: PlatformColor) -> Bool {
        let c = color.sRGBComponents()
        let label = defaultLabelComponents
        let threshold: CGFloat = 0.1
        return abs(c.r - label.r) < threshold && abs(c.g - label.g) < threshold && abs(c.b - label.b) < threshold
    }
}

private struct ScrollMetrics: Equatable {
    let offset: CGFloat
    let contentHeight: CGFloat
}

struct CenterLineIndicator: View {
    var body: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.red.opacity(0.5))
                .frame(height: 2)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
