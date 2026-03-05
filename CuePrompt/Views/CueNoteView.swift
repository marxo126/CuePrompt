import SwiftUI

struct CueNoteView: View {
    let text: String
    var fontSize: Double = 18

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: fontSize * 0.8))
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .italic()
        }
        .foregroundStyle(.yellow)
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}
