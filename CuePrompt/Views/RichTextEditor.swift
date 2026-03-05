import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Formatting Coordinator

@Observable
final class FormattingCoordinator {
    var isBold = false
    var isItalic = false
    var isUnderline = false
    var currentFontSize: CGFloat = RichTextCoordinatorCore.defaultFontSize
    var currentTextColor: PlatformColor = .defaultLabelColor
    var currentHighlightColor: PlatformColor? = nil
    var currentAlignment: NSTextAlignment = .left

    var pendingAction: FormattingAction?

    enum FormattingAction {
        case toggleBold
        case toggleItalic
        case toggleUnderline
        case setFontSize(CGFloat)
        case setTextColor(PlatformColor)
        case setHighlightColor(PlatformColor?)
        case setAlignment(NSTextAlignment)
        case clearFormatting
    }
}

// MARK: - Platform Type Aliases

#if os(macOS)
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#else
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#endif

extension PlatformColor {
    static var defaultLabelColor: PlatformColor {
        #if os(macOS)
        return NSColor.labelColor
        #else
        return UIColor.label
        #endif
    }

    func sRGBComponents() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(macOS)
        let resolved = usingColorSpace(.sRGB) ?? self
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (r, g, b, a)
    }
}

// MARK: - Cross-Platform Font Extensions

extension PlatformFont {
    static func defaultFont(ofSize size: CGFloat) -> PlatformFont {
        .systemFont(ofSize: size)
    }

    func hasBoldTrait() -> Bool {
        #if os(macOS)
        fontDescriptor.symbolicTraits.contains(.bold)
        #else
        fontDescriptor.symbolicTraits.contains(.traitBold)
        #endif
    }

    func hasItalicTrait() -> Bool {
        #if os(macOS)
        fontDescriptor.symbolicTraits.contains(.italic)
        #else
        fontDescriptor.symbolicTraits.contains(.traitItalic)
        #endif
    }

    func withBold(_ enabled: Bool) -> PlatformFont {
        #if os(macOS)
        let manager = NSFontManager.shared
        return enabled
            ? manager.convert(self, toHaveTrait: .boldFontMask)
            : manager.convert(self, toNotHaveTrait: .boldFontMask)
        #else
        var traits = fontDescriptor.symbolicTraits
        if enabled { traits.insert(.traitBold) } else { traits.remove(.traitBold) }
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
        #endif
    }

    func withItalic(_ enabled: Bool) -> PlatformFont {
        #if os(macOS)
        let manager = NSFontManager.shared
        return enabled
            ? manager.convert(self, toHaveTrait: .italicFontMask)
            : manager.convert(self, toNotHaveTrait: .italicFontMask)
        #else
        var traits = fontDescriptor.symbolicTraits
        if enabled { traits.insert(.traitItalic) } else { traits.remove(.traitItalic) }
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
        #endif
    }

    func withPointSize(_ size: CGFloat) -> PlatformFont {
        #if os(macOS)
        return NSFont(descriptor: fontDescriptor, size: size) ?? self
        #else
        return withSize(size)
        #endif
    }
}

// MARK: - Shared Coordinator Logic

struct RichTextCoordinatorCore {
    static let defaultFontSize: CGFloat = 16

    static var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: PlatformFont.defaultFont(ofSize: defaultFontSize), .foregroundColor: PlatformColor.defaultLabelColor]
    }

    let script: Script
    var formattingCoordinator: FormattingCoordinator

    func updateFormattingState(selectedRange: NSRange, storage: NSTextStorage) {
        guard storage.length > 0 else { return }
        let checkIndex = selectedRange.location > 0 ? selectedRange.location - 1 : 0
        guard checkIndex < storage.length else { return }

        let attrs = storage.attributes(at: checkIndex, effectiveRange: nil)

        if let font = attrs[.font] as? PlatformFont {
            formattingCoordinator.isBold = font.hasBoldTrait()
            formattingCoordinator.isItalic = font.hasItalicTrait()
            formattingCoordinator.currentFontSize = font.pointSize
        }

        formattingCoordinator.isUnderline = ((attrs[.underlineStyle] as? Int) ?? 0) != 0
        formattingCoordinator.currentTextColor = (attrs[.foregroundColor] as? PlatformColor) ?? .defaultLabelColor
        formattingCoordinator.currentHighlightColor = attrs[.backgroundColor] as? PlatformColor

        if let paragraph = attrs[.paragraphStyle] as? NSParagraphStyle {
            formattingCoordinator.currentAlignment = paragraph.alignment
        }
    }

    func applyToStorage(_ action: FormattingCoordinator.FormattingAction, storage: NSTextStorage, range: NSRange) {
        storage.beginEditing()
        switch action {
        case .toggleBold:
            toggleBold(in: range, storage: storage)
        case .toggleItalic:
            toggleItalic(in: range, storage: storage)
        case .toggleUnderline:
            let current = storage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
            let newVal = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            storage.addAttribute(.underlineStyle, value: newVal, range: range)
        case .setFontSize(let size):
            storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
                let font = (value as? PlatformFont) ?? .defaultFont(ofSize: size)
                storage.addAttribute(.font, value: font.withPointSize(size), range: subRange)
            }
        case .setTextColor(let color):
            storage.addAttribute(.foregroundColor, value: color, range: range)
        case .setHighlightColor(let color):
            if let color = color {
                storage.addAttribute(.backgroundColor, value: color, range: range)
            } else {
                storage.removeAttribute(.backgroundColor, range: range)
            }
        case .setAlignment(let alignment):
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            storage.addAttribute(.paragraphStyle, value: paragraph, range: range)
        case .clearFormatting:
            let plainText = storage.attributedSubstring(from: range).string
            storage.replaceCharacters(in: range, with: NSAttributedString(string: plainText, attributes: RichTextCoordinatorCore.defaultAttributes))
        }
        storage.endEditing()
    }

    func applyToTypingAttributes(_ action: FormattingCoordinator.FormattingAction, attrs: inout [NSAttributedString.Key: Any]) {
        switch action {
        case .toggleBold:
            let font = (attrs[.font] as? PlatformFont) ?? .defaultFont(ofSize: RichTextCoordinatorCore.defaultFontSize)
            attrs[.font] = font.withBold(!font.hasBoldTrait())
        case .toggleItalic:
            let font = (attrs[.font] as? PlatformFont) ?? .defaultFont(ofSize: RichTextCoordinatorCore.defaultFontSize)
            attrs[.font] = font.withItalic(!font.hasItalicTrait())
        case .toggleUnderline:
            let current = attrs[.underlineStyle] as? Int ?? 0
            attrs[.underlineStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
        case .setFontSize(let size):
            let font = (attrs[.font] as? PlatformFont) ?? .defaultFont(ofSize: size)
            attrs[.font] = font.withPointSize(size)
        case .setTextColor(let color):
            attrs[.foregroundColor] = color
        case .setHighlightColor(let color):
            if let color = color {
                attrs[.backgroundColor] = color
            } else {
                attrs.removeValue(forKey: .backgroundColor)
            }
        case .setAlignment(let alignment):
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            attrs[.paragraphStyle] = paragraph
        case .clearFormatting:
            attrs = RichTextCoordinatorCore.defaultAttributes
        }
    }

    private func toggleBold(in range: NSRange, storage: NSTextStorage) {
        storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
            let font = (value as? PlatformFont) ?? .defaultFont(ofSize: RichTextCoordinatorCore.defaultFontSize)
            storage.addAttribute(.font, value: font.withBold(!font.hasBoldTrait()), range: subRange)
        }
    }

    private func toggleItalic(in range: NSRange, storage: NSTextStorage) {
        storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
            let font = (value as? PlatformFont) ?? .defaultFont(ofSize: RichTextCoordinatorCore.defaultFontSize)
            storage.addAttribute(.font, value: font.withItalic(!font.hasItalicTrait()), range: subRange)
        }
    }
}

// MARK: - macOS Rich Text Editor

#if os(macOS)

struct RichTextEditor: NSViewRepresentable {
    @Bindable var script: Script
    var formattingState: FormattingCoordinator

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = .textBackgroundColor
        textView.delegate = context.coordinator
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        if let attrString = script.attributedString {
            textView.textStorage?.setAttributedString(attrString)
        } else if !script.body.isEmpty {
            textView.textStorage?.setAttributedString(NSAttributedString(string: script.body, attributes: RichTextCoordinatorCore.defaultAttributes))
        }

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let action = formattingState.pendingAction {
            formattingState.pendingAction = nil
            context.coordinator.applyAction(action)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(script: script, formattingCoordinator: formattingState)
    }

    @MainActor class Coordinator: NSObject, NSTextViewDelegate {
        var core: RichTextCoordinatorCore
        weak var textView: NSTextView?
        private var isUpdating = false
        private var saveWorkItem: DispatchWorkItem?

        init(script: Script, formattingCoordinator: FormattingCoordinator) {
            self.core = RichTextCoordinatorCore(script: script, formattingCoordinator: formattingCoordinator)
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = textView else { return }
            isUpdating = true
            core.script.body = textView.string
            core.script.updatedAt = Date()
            scheduleSave(from: textView)
            isUpdating = false
        }

        private func scheduleSave(from textView: NSTextView) {
            saveWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, let textView = self.textView else { return }
                self.core.script.setAttributedString(NSAttributedString(attributedString: textView.attributedString()))
            }
            saveWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = textView, let storage = textView.textStorage else { return }
            core.updateFormattingState(selectedRange: textView.selectedRange(), storage: storage)
        }

        func applyAction(_ action: FormattingCoordinator.FormattingAction) {
            guard let textView = textView, let storage = textView.textStorage else { return }
            var range = textView.selectedRange()
            if range.length == 0 {
                var attrs = textView.typingAttributes
                core.applyToTypingAttributes(action, attrs: &attrs)
                textView.typingAttributes = attrs
                core.updateFormattingState(selectedRange: range, storage: storage)
                return
            }

            range = NSIntersectionRange(range, NSRange(location: 0, length: storage.length))
            guard range.length > 0 else { return }

            core.applyToStorage(action, storage: storage, range: range)
            core.script.setAttributedString(NSAttributedString(attributedString: textView.attributedString()))
            core.updateFormattingState(selectedRange: textView.selectedRange(), storage: storage)
        }
    }
}

#else

// MARK: - iOS Rich Text Editor

struct RichTextEditor: UIViewRepresentable {
    @Bindable var script: Script
    var formattingState: FormattingCoordinator

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.font = UIFont.systemFont(ofSize: RichTextCoordinatorCore.defaultFontSize)
        textView.backgroundColor = .systemBackground
        textView.delegate = context.coordinator

        if let attrString = script.attributedString {
            textView.attributedText = attrString
        } else if !script.body.isEmpty {
            textView.attributedText = NSAttributedString(string: script.body, attributes: RichTextCoordinatorCore.defaultAttributes)
        }

        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if let action = formattingState.pendingAction {
            formattingState.pendingAction = nil
            context.coordinator.applyAction(action)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(script: script, formattingCoordinator: formattingState)
    }

    @MainActor class Coordinator: NSObject, UITextViewDelegate {
        var core: RichTextCoordinatorCore
        weak var textView: UITextView?
        private var isUpdating = false
        private var saveWorkItem: DispatchWorkItem?

        init(script: Script, formattingCoordinator: FormattingCoordinator) {
            self.core = RichTextCoordinatorCore(script: script, formattingCoordinator: formattingCoordinator)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            isUpdating = true
            core.script.body = textView.text
            core.script.updatedAt = Date()
            scheduleSave(from: textView)
            isUpdating = false
        }

        private func scheduleSave(from textView: UITextView) {
            saveWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, let textView = self.textView else { return }
                self.core.script.setAttributedString(NSAttributedString(attributedString: textView.attributedText))
            }
            saveWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            core.updateFormattingState(selectedRange: textView.selectedRange, storage: textView.textStorage)
        }

        func applyAction(_ action: FormattingCoordinator.FormattingAction) {
            guard let textView = textView else { return }
            let storage = textView.textStorage
            var range = textView.selectedRange
            if range.length == 0 {
                var attrs = textView.typingAttributes
                core.applyToTypingAttributes(action, attrs: &attrs)
                textView.typingAttributes = attrs
                core.updateFormattingState(selectedRange: range, storage: storage)
                return
            }

            range = NSIntersectionRange(range, NSRange(location: 0, length: storage.length))
            guard range.length > 0 else { return }

            core.applyToStorage(action, storage: storage, range: range)
            core.script.setAttributedString(NSAttributedString(attributedString: textView.attributedText))
            core.updateFormattingState(selectedRange: textView.selectedRange, storage: storage)
        }
    }
}

#endif
