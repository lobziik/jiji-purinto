//
//  PreviewScreen.swift
//  jiji-purinto
//
//  Preview screen showing processed image with print button.
//

import SwiftUI

/// Screen for previewing the processed image before printing.
///
/// Designed for toddler-friendly interaction:
/// - Large preview image
/// - Simple print button
/// - Settings accessible via gear icon (for adults)
struct PreviewScreen: View {
    /// The app coordinator for sending events.
    @ObservedObject var coordinator: AppCoordinator

    /// The image to preview.
    let image: UIImage

    /// Current image settings.
    let settings: ImageSettings

    /// Navigation back action (for v0.1, just going back to home).
    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")

                Spacer()

                // Processing indicator
                if coordinator.isProcessing {
                    ProgressView()
                        .frame(width: 44, height: 44)
                }

                // Settings button
                Button {
                    coordinator.showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 8)

            Spacer()

            // Image preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .opacity(coordinator.isProcessing ? 0.5 : 1.0)

            Spacer()

            // Print button
            BigButton("Print", systemImage: "printer") {
                Task {
                    do {
                        try await coordinator.printCurrentImage()
                    } catch {
                        // Error is already handled by AppCoordinator (transitions to error state)
                        // Log for debugging purposes
                        print("Print failed: \(error)")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(coordinator.printerReady ? 1.0 : 0.5)
            .disabled(coordinator.isProcessing)
            .accessibilityLabel(coordinator.printerReady ? "Print" : "Print (printer not connected)")
        }
        .sheet(isPresented: $coordinator.showingSettings) {
            SettingsSheet(settings: $coordinator.imageSettings, coordinator: coordinator)
        }
        .onChange(of: coordinator.imageSettings) { _ in
            // Reprocess image when settings change
            Task {
                await coordinator.reprocessWithCurrentSettings()
            }
        }
    }
}

// MARK: - Previews

#Preview("Preview Screen") {
    let coordinator = AppCoordinator()
    // Create a placeholder image for preview
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 384, height: 500))
    let image = renderer.image { context in
        UIColor.lightGray.setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 384, height: 500)))

        // Draw a simple placeholder pattern
        UIColor.darkGray.setFill()
        for i in stride(from: 20, to: 380, by: 40) {
            context.fill(CGRect(x: i, y: 20, width: 20, height: 460))
        }
    }

    return PreviewScreen(
        coordinator: coordinator,
        image: image,
        settings: .default
    )
}

#Preview("Preview Screen - Printer Status") {
    let coordinator = AppCoordinator()
    // Note: printerReady is now controlled by printerCoordinator

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 384, height: 500))
    let image = renderer.image { context in
        UIColor.systemBlue.withAlphaComponent(0.3).setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 384, height: 500)))
    }

    PreviewScreen(
        coordinator: coordinator,
        image: image,
        settings: .default
    )
}
