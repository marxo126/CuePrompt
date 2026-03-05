import Foundation
import SwiftData

@Model
final class Script {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "Untitled Script", body: String = "") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Parses the body text and extracts segments including inline cues.
    /// Cues use the syntax [CUE: text]
    var segments: [ScriptSegment] {
        var result: [ScriptSegment] = []
        let pattern = #"\[CUE:\s*(.*?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(body)]
        }

        let nsBody = body as NSString
        var lastEnd = 0

        let matches = regex.matches(in: body, options: [], range: NSRange(location: 0, length: nsBody.length))
        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: matchRange.location - lastEnd)
                let text = nsBody.substring(with: textRange)
                if !text.isEmpty {
                    result.append(.text(text))
                }
            }
            if match.numberOfRanges > 1 {
                let cueText = nsBody.substring(with: match.range(at: 1))
                result.append(.cue(cueText))
            }
            lastEnd = matchRange.location + matchRange.length
        }

        if lastEnd < nsBody.length {
            let remaining = nsBody.substring(from: lastEnd)
            if !remaining.isEmpty {
                result.append(.text(remaining))
            }
        }

        if result.isEmpty && !body.isEmpty {
            result.append(.text(body))
        }

        return result
    }
}

enum ScriptSegment: Identifiable {
    case text(String)
    case cue(String)

    var id: String {
        switch self {
        case .text(let s): return "text-\(s.hashValue)"
        case .cue(let s): return "cue-\(s.hashValue)"
        }
    }

    var isCue: Bool {
        if case .cue = self { return true }
        return false
    }

    var content: String {
        switch self {
        case .text(let s): return s
        case .cue(let s): return s
        }
    }
}
