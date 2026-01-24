//
//  PrinterSettingsSheet.swift
//  jiji-purinto
//
//  Sheet for configuring printer hardware settings.
//

import SwiftUI
import os

/// Logger for printer settings sheet operations.
private let settingsSheetLogger = Logger(subsystem: "com.jiji-purinto", category: "PrinterSettingsSheet")

/// Sheet for configuring printer quality and energy settings.
///
/// Changes are applied immediately to the connected printer.
/// Settings persist between sessions and are restored on reconnect.
struct PrinterSettingsSheet: View {
    /// Binding to the current printer settings.
    @Binding var settings: PrinterSettings

    /// Whether a printer is currently connected.
    ///
    /// When `false`, controls are disabled but settings are still viewable.
    /// Settings are persisted and will be synced on next connection.
    let isConnected: Bool

    /// Callback to apply settings to the printer.
    ///
    /// Called when the user changes a setting. The callback should send
    /// the appropriate commands to the printer.
    var onSettingsChanged: (PrinterSettings) async throws -> Void

    /// Dismiss action for the sheet.
    @Environment(\.dismiss) private var dismiss

    /// Error message to display if applying settings fails.
    @State private var errorMessage: String?

    /// Whether an error alert is showing.
    @State private var showingError = false

    /// Local copy of energy for slider (to avoid sending commands while dragging).
    @State private var localEnergyPercent: Double = 0

    var body: some View {
        NavigationView {
            formContent
                .navigationTitle("Printer Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .alert("Settings Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    if let errorMessage {
                        Text(errorMessage)
                    }
                }
                .onAppear {
                    localEnergyPercent = Double(settings.energyPercent)
                }
        }
        .navigationViewStyle(.stack)
    }

    /// The main form content, extracted to simplify type inference.
    private var formContent: some View {
        Form {
            printerStatusSection
            qualitySection
                .disabled(!isConnected)
            energySection
                .disabled(!isConnected)
            resetSection
                .disabled(!isConnected)
            aboutSection
        }
    }

    /// Quality picker section.
    private var qualitySection: some View {
        Section {
            Picker("Quality", selection: $settings.quality) {
                ForEach(PrinterQuality.allCases, id: \.self) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.quality) { newValue in
                settingsSheetLogger.info("Quality picker changed to: \(newValue.rawValue)")
                applyCurrentSettings()
            }
        } header: {
            Label("Print Quality", systemImage: "slider.horizontal.3")
        } footer: {
            Text("Higher quality produces darker prints but uses more energy.")
        }
    }

    /// Energy slider section.
    private var energySection: some View {
        Section {
            HStack {
                Image(systemName: "thermometer.snowflake")
                    .foregroundColor(.blue)

                Slider(
                    value: $localEnergyPercent,
                    in: 0...100,
                    step: 1,
                    onEditingChanged: { editing in
                        if !editing {
                            let oldValue = settings.energyPercent
                            settings.energyPercent = Int(localEnergyPercent)
                            settingsSheetLogger.info("Energy slider released: \(oldValue)% -> \(Int(self.localEnergyPercent))%")
                            applyCurrentSettings()
                        }
                    }
                )

                Image(systemName: "thermometer.sun.fill")
                    .foregroundColor(.orange)
            }

            HStack {
                Spacer()
                Text("\(Int(localEnergyPercent))%")
                    .font(.headline)
                    .monospacedDigit()
                Spacer()
            }
        } header: {
            Label("Energy Level", systemImage: "bolt.fill")
        } footer: {
            Text("Higher energy produces darker prints but may cause overheating on long prints. Default is 37%.")
        }
    }

    /// Reset button section.
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                resetToDefaults()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
            }
        }
    }

    /// Printer connection status section.
    private var printerStatusSection: some View {
        Section {
            HStack {
                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connected")
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("No printer connected")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        } footer: {
            if !isConnected {
                Text("Settings will be applied when a printer connects.")
            }
        }
    }

    /// About section with app version and links.
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://github.com/lobziik/jiji-purinto")!) {
                HStack {
                    Text("GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    /// App version string from Bundle.
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    /// Applies the current settings to the printer.
    private func applyCurrentSettings() {
        settingsSheetLogger.info("applyCurrentSettings: sending quality=\(self.settings.quality.rawValue), energy=\(self.settings.energyPercent)% to printer")
        Task {
            do {
                try await onSettingsChanged(settings)
                settingsSheetLogger.info("applyCurrentSettings: SUCCESS")
            } catch {
                settingsSheetLogger.error("applyCurrentSettings: FAILED - \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    /// Resets settings to defaults and applies them.
    private func resetToDefaults() {
        settingsSheetLogger.info("resetToDefaults: resetting to quality=\(PrinterSettings.default.quality.rawValue), energy=\(PrinterSettings.default.energyPercent)%")
        settings = .default
        localEnergyPercent = Double(PrinterSettings.default.energyPercent)
        applyCurrentSettings()
    }
}

// MARK: - Previews

#Preview("Printer Settings - Connected") {
    PrinterSettingsSheet(
        settings: .constant(.default),
        isConnected: true,
        onSettingsChanged: { _ in }
    )
}

#Preview("Printer Settings - Disconnected") {
    PrinterSettingsSheet(
        settings: .constant(.default),
        isConnected: false,
        onSettingsChanged: { _ in }
    )
}
