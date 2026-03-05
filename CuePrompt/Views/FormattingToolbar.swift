import SwiftUI

struct FormattingToolbar: View {
    var coordinator: FormattingCoordinator

    private let fontSizes: [CGFloat] = [14, 16, 18, 20, 24, 28, 32]

    private let basicColors: [(String, PlatformColor)] = [
        ("Black", PlatformColor.defaultLabelColor),
        ("Red", PlatformColor.systemRed),
        ("Blue", PlatformColor.systemBlue),
        ("Green", PlatformColor.systemGreen),
        ("Orange", PlatformColor.systemOrange),
        ("Purple", PlatformColor.systemPurple),
    ]

    private let highlightColors: [(String, PlatformColor?)] = [
        ("None", nil),
        ("Yellow", PlatformColor.systemYellow),
        ("Green", PlatformColor.systemGreen),
        ("Blue", PlatformColor.systemBlue),
        ("Pink", PlatformColor.systemPink),
    ]

    var body: some View {
        HStack(spacing: 4) {
            // Bold, Italic, Underline
            Group {
                toolbarButton(label: "B", isActive: coordinator.isBold, fontWeight: .bold) {
                    coordinator.pendingAction = .toggleBold
                }
                .keyboardShortcut("b", modifiers: .command)

                toolbarButton(label: "I", isActive: coordinator.isItalic, fontWeight: .regular, italic: true) {
                    coordinator.pendingAction = .toggleItalic
                }
                .keyboardShortcut("i", modifiers: .command)

                toolbarButton(label: "U", isActive: coordinator.isUnderline, fontWeight: .regular, underline: true) {
                    coordinator.pendingAction = .toggleUnderline
                }
                .keyboardShortcut("u", modifiers: .command)
            }

            Divider().frame(height: 20)

            // Font size picker
            Menu {
                ForEach(fontSizes, id: \.self) { size in
                    Button {
                        coordinator.pendingAction = .setFontSize(size)
                    } label: {
                        HStack {
                            Text("\(Int(size)) pt")
                            if abs(coordinator.currentFontSize - size) < 0.5 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text("\(Int(coordinator.currentFontSize))")
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: 28)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
            .fixedSize()

            Divider().frame(height: 20)

            // Text color
            Menu {
                ForEach(basicColors, id: \.0) { name, color in
                    Button {
                        coordinator.pendingAction = .setTextColor(color)
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(color))
                                .frame(width: 10, height: 10)
                            Text(name)
                        }
                    }
                }
            } label: {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 12))
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
            .fixedSize()

            // Highlight color
            Menu {
                ForEach(highlightColors, id: \.0) { name, color in
                    Button {
                        coordinator.pendingAction = .setHighlightColor(color)
                    } label: {
                        HStack {
                            if let color {
                                Circle()
                                    .fill(Color(color))
                                    .frame(width: 10, height: 10)
                            } else {
                                Circle()
                                    .strokeBorder(Color.secondary, lineWidth: 1)
                                    .frame(width: 10, height: 10)
                            }
                            Text(name)
                        }
                    }
                }
            } label: {
                Image(systemName: "highlighter")
                    .font(.system(size: 12))
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
            .fixedSize()

            Divider().frame(height: 20)

            // Alignment
            Group {
                toolbarIconButton(icon: "text.alignleft", isActive: coordinator.currentAlignment == .left) {
                    coordinator.pendingAction = .setAlignment(.left)
                }
                toolbarIconButton(icon: "text.aligncenter", isActive: coordinator.currentAlignment == .center) {
                    coordinator.pendingAction = .setAlignment(.center)
                }
                toolbarIconButton(icon: "text.alignright", isActive: coordinator.currentAlignment == .right) {
                    coordinator.pendingAction = .setAlignment(.right)
                }
            }

            Divider().frame(height: 20)

            // Clear formatting
            Button {
                coordinator.pendingAction = .clearFormatting
            } label: {
                Image(systemName: "textformat")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.red)
                            .offset(x: 2, y: 2)
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(PlatformColor.separatorColor).opacity(0.1))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func styledButton(isActive: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func toolbarButton(label: String, isActive: Bool, fontWeight: Font.Weight, italic: Bool = false, underline: Bool = false, action: @escaping () -> Void) -> some View {
        styledButton(isActive: isActive, action: action) {
            Text(label)
                .font(.system(size: 14, weight: fontWeight))
                .italic(italic)
                .underline(underline)
        }
    }

    @ViewBuilder
    private func toolbarIconButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        styledButton(isActive: isActive, action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
        }
    }
}

// MARK: - Platform color helpers for SwiftUI

#if os(iOS)
extension PlatformColor {
    static var separatorColor: UIColor { .separator }
}
#endif
