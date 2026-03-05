import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Font
                Section("Font") {
                    HStack {
                        Text("Font Size: \(Int(settings.fontSize))pt")
                        Spacer()
                        Slider(value: $settings.fontSize, in: 16...72, step: 1)
                            .frame(maxWidth: 200)
                    }

                    ColorPicker("Font Color", selection: $settings.fontColor)
                    ColorPicker("Background Color", selection: $settings.backgroundColor)

                    HStack {
                        Text("Line Spacing: \(Int(settings.lineSpacing))")
                        Spacer()
                        Slider(value: $settings.lineSpacing, in: 4...40, step: 1)
                            .frame(maxWidth: 200)
                    }

                    HStack {
                        Text("Horizontal Padding: \(Int(settings.horizontalPadding))")
                        Spacer()
                        Slider(value: $settings.horizontalPadding, in: 8...80, step: 4)
                            .frame(maxWidth: 200)
                    }
                }

                // MARK: - Scrolling
                Section("Scrolling") {
                    HStack {
                        Text("Default Speed: \(String(format: "%.1fx", settings.defaultScrollSpeed))")
                        Spacer()
                        Slider(value: $settings.defaultScrollSpeed, in: AppSettings.speedMin...AppSettings.speedMax, step: AppSettings.speedStep)
                            .frame(maxWidth: 200)
                    }

                    Toggle("Mirror Mode", isOn: $settings.isMirrored)
                }

                // MARK: - Timer
                Section("Timer") {
                    Picker("Timer Mode", selection: $settings.timerMode) {
                        ForEach(AppSettings.TimerMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    if settings.timerMode == .countdown {
                        Stepper(
                            "Countdown: \(settings.countdownStartSeconds / 60)m \(settings.countdownStartSeconds % 60)s",
                            value: $settings.countdownStartSeconds,
                            in: 30...3600,
                            step: 30
                        )

                        Stepper(
                            "Warning at \(settings.timerWarningThreshold)s",
                            value: $settings.timerWarningThreshold,
                            in: 10...120,
                            step: 5
                        )
                    }
                }

                #if os(macOS)
                // MARK: - Floating Window
                Section("Floating Window (macOS)") {
                    HStack {
                        Text("Opacity: \(Int(settings.floatingWindowOpacity * 100))%")
                        Spacer()
                        Slider(value: $settings.floatingWindowOpacity, in: 0.3...1.0, step: 0.05)
                            .frame(maxWidth: 200)
                    }
                }
                #endif

                // MARK: - Preview
                Section("Preview") {
                    ZStack {
                        settings.backgroundColor
                        VStack(spacing: settings.lineSpacing) {
                            Text("Sample teleprompter text")
                                .font(.system(size: min(settings.fontSize, 28), weight: .medium))
                                .foregroundStyle(settings.fontColor)
                            Text("[CUE: stage direction]")
                                .font(.system(size: min(settings.fontSize, 28) * 0.65))
                                .foregroundStyle(.yellow)
                                .italic()
                        }
                        .padding(settings.horizontalPadding)
                        .scaleEffect(x: settings.isMirrored ? -1 : 1, y: 1)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settings.save()
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }
}
