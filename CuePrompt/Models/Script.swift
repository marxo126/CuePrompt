import Foundation
import SwiftData

nonisolated(unsafe) private let cueRegex = /\[CUE:\s*(.*?)\]/

@Model
final class Script {
    var id: UUID
    var title: String
    var body: String
    var attributedBody: Data?
    var createdAt: Date
    var updatedAt: Date

    @Transient private var cachedBody: String?
    @Transient private var cachedSegments: [ScriptSegment] = []
    @Transient private var cachedAttrData: Data?
    @Transient private var cachedAttrString: NSAttributedString?

    init(title: String = "Untitled Script", body: String = "") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.attributedBody = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var attributedString: NSAttributedString? {
        guard let data = attributedBody else { return nil }
        if cachedAttrData == data { return cachedAttrString }
        cachedAttrData = data
        // Try RTF first, fall back to RTFD for existing data
        cachedAttrString = (try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )) ?? (try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        ))
        return cachedAttrString
    }

    /// Store an NSAttributedString as RTFD data
    func setAttributedString(_ attrString: NSAttributedString) {
        let range = NSRange(location: 0, length: attrString.length)
        attributedBody = try? attrString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        body = attrString.string
        updatedAt = Date()
    }

    var segments: [ScriptSegment] {
        if cachedBody == body { return cachedSegments }
        cachedBody = body
        cachedSegments = Self.parseSegments(body)
        return cachedSegments
    }

    private static func parseSegments(_ body: String) -> [ScriptSegment] {
        var result: [ScriptSegment] = []
        var lastEnd = body.startIndex
        var index = 0

        for match in body.matches(of: cueRegex) {
            let matchStart = match.range.lowerBound
            if matchStart > lastEnd {
                result.append(.text(String(body[lastEnd..<matchStart]), index))
                index += 1
            }
            result.append(.cue(String(match.output.1), index))
            index += 1
            lastEnd = match.range.upperBound
        }

        if lastEnd < body.endIndex {
            result.append(.text(String(body[lastEnd...]), index))
        }

        if result.isEmpty && !body.isEmpty {
            result.append(.text(body, 0))
        }

        return result
    }
}

enum ScriptSegment: Identifiable {
    case text(String, Int)
    case cue(String, Int)

    var id: Int {
        switch self {
        case .text(_, let i), .cue(_, let i): return i
        }
    }
}
