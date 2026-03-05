import SwiftUI

struct TimerView: View {
    var viewModel: TeleprompterViewModel

    var body: some View {
        Text(viewModel.timerDisplay)
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(viewModel.timerColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
