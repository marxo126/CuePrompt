import Foundation

/// Represents a cue note that can be rendered inline in the teleprompter.
struct CueNote: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var type: CueType

    init(id: UUID = UUID(), text: String, type: CueType = .note) {
        self.id = id
        self.text = text
        self.type = type
    }

    enum CueType: String, Codable, CaseIterable, Hashable {
        case note
        case direction
        case emphasis

        var label: String {
            switch self {
            case .note: return "Note"
            case .direction: return "Direction"
            case .emphasis: return "Emphasis"
            }
        }
    }
}
