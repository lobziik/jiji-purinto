//
//  SettingsSheet.swift
//  jiji-purinto
//
//  Settings sheet for adjusting image processing parameters.
//

import SwiftUI

/// Sheet for adjusting image processing settings with live preview.
///
/// Provides controls for:
/// - Auto levels toggle (histogram stretching)
/// - Gamma correction (0.8 to 2.0)
/// - Brightness adjustment (-1.0 to +1.0)
/// - Contrast adjustment (0.5 to 2.0)
/// - Dithering algorithm selection
/// - Reset to defaults
///
/// ## Design
/// - Sliders for brightness/contrast with current value display
/// - Segmented picker for dithering algorithm
/// - Reset button to restore default settings
/// - Live preview updates via binding
struct SettingsSheet: View {
    /// Binding to the current image settings.
    @Binding var settings: ImageSettings

    /// Dismiss action for the sheet.
    @Environment(\.dismiss) private var dismiss

    /// Original settings for reset functionality.
    private let defaultSettings: ImageSettings = .default

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Auto Levels Section

                Section {
                    Toggle("Auto Levels", isOn: $settings.autoLevels)
                } header: {
                    Text("Auto Levels")
                } footer: {
                    Text("Automatically stretch image contrast to use full dynamic range. Recommended for most images.")
                }

                // MARK: - Gamma Section

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Gamma")
                            Spacer()
                            Text(gammaText)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $settings.gamma,
                            in: 0.8...2.0,
                            step: 0.1
                        ) {
                            Text("Gamma")
                        } minimumValueLabel: {
                            Image(systemName: "moon")
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "sun.max")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityValue(gammaText)
                    }
                } header: {
                    Text("Gamma")
                } footer: {
                    Text("Adjust midtone brightness. Higher values brighten the image for better thermal prints.")
                }

                // MARK: - Brightness Section

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Brightness")
                            Spacer()
                            Text(brightnessText)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $settings.brightness,
                            in: -1.0...1.0,
                            step: 0.05
                        ) {
                            Text("Brightness")
                        } minimumValueLabel: {
                            Image(systemName: "sun.min")
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "sun.max")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityValue(brightnessText)
                    }
                } header: {
                    Text("Brightness")
                } footer: {
                    Text("Adjust overall image brightness. Positive values brighten, negative values darken.")
                }

                // MARK: - Contrast Section

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Contrast")
                            Spacer()
                            Text(contrastText)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $settings.contrast,
                            in: 0.5...2.0,
                            step: 0.05
                        ) {
                            Text("Contrast")
                        } minimumValueLabel: {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "circle.lefthalf.striped.horizontal")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityValue(contrastText)
                    }
                } header: {
                    Text("Contrast")
                } footer: {
                    Text("Adjust difference between light and dark areas. Higher values increase contrast.")
                }

                // MARK: - Algorithm Section

                Section {
                    Picker("Algorithm", selection: $settings.algorithm) {
                        ForEach(DitherAlgorithm.allCases, id: \.self) { algorithm in
                            Text(algorithm.displayName)
                                .tag(algorithm)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Dithering Algorithm")
                } footer: {
                    Text(settings.algorithm.description)
                }

                // MARK: - Reset Section

                Section {
                    Button(role: .destructive) {
                        withAnimation {
                            settings = defaultSettings
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                    .disabled(settings == defaultSettings)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Computed Properties

    private var brightnessText: String {
        if settings.brightness >= 0 {
            return String(format: "+%.2f", settings.brightness)
        } else {
            return String(format: "%.2f", settings.brightness)
        }
    }

    private var contrastText: String {
        String(format: "%.2f", settings.contrast)
    }

    private var gammaText: String {
        String(format: "%.1f", settings.gamma)
    }
}

// MARK: - DitherAlgorithm Display Extensions

extension DitherAlgorithm {
    /// User-friendly display name.
    var displayName: String {
        switch self {
        case .threshold:
            return "Threshold"
        case .floydSteinberg:
            return "Floyd-Steinberg"
        case .atkinson:
            return "Atkinson"
        case .ordered:
            return "Ordered"
        }
    }

    /// Description of the algorithm for user education.
    var description: String {
        switch self {
        case .threshold:
            return "Simple black/white cutoff. Best for text and line art."
        case .floydSteinberg:
            return "Error diffusion dithering. Best for photographs."
        case .atkinson:
            return "Vintage Mac-style dithering. Creates a retro look."
        case .ordered:
            return "Pattern-based dithering. Creates regular crosshatch patterns."
        }
    }
}

// MARK: - Previews

#Preview("Settings Sheet") {
    struct PreviewWrapper: View {
        @State private var settings: ImageSettings = .default

        var body: some View {
            SettingsSheet(settings: $settings)
        }
    }

    return PreviewWrapper()
}

#Preview("Settings Sheet - Modified") {
    struct PreviewWrapper: View {
        @State private var settings = ImageSettings(
            brightness: 0.3,
            contrast: 1.5,
            algorithm: .atkinson,
            gamma: 1.8,
            autoLevels: false,
            clipPercent: 2.0
        )

        var body: some View {
            SettingsSheet(settings: $settings)
        }
    }

    return PreviewWrapper()
}
