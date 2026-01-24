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
                // Left side: navigation
                HStack(spacing: 0) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Back")

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

                Spacer()

                // Processing indicator (center)
                if coordinator.isProcessing {
                    ProgressView()
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Right side: actions
                HStack(spacing: 0) {
                    // Share button
                    Button {
                        prepareAndShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(coordinator.isProcessing)
                    .accessibilityLabel("Share")

                    // Printer status indicator
                    PrinterStatusView(printerCoordinator: coordinator.printerCoordinator)
                }
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
            HStack(spacing: 16) {
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
                .opacity(coordinator.printerReady ? 1.0 : 0.5)
                .disabled(coordinator.isProcessing)
                .accessibilityLabel(coordinator.printerReady ? "Print" : "Print (printer not connected)")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $coordinator.showingSettings) {
            SettingsSheet(settings: $coordinator.imageSettings)
        }
        .onChange(of: coordinator.imageSettings) { _ in
            // Reprocess image when settings change
            Task {
                await coordinator.reprocessWithCurrentSettings()
            }
        }
    }

    // MARK: - Private Methods

    /// Prepares the image at print resolution and shows the share sheet.
    private func prepareAndShare() {
        print("[Share] Button tapped - starting")
        // Use detached task to avoid inheriting MainActor context
        // This ensures image processing doesn't block the UI
        let coordinator = self.coordinator
        print("[Share] Creating detached task")
        Task.detached(priority: .userInitiated) {
            print("[Share] Detached task started")
            do {
                print("[Share] Calling getShareableImage...")
                let image = try await coordinator.getShareableImage()
                print("[Share] Got image, presenting sheet...")
                await MainActor.run {
                    print("[Share] On MainActor, calling ShareSheet.present")
                    ShareSheet.present(items: [image])
                    print("[Share] ShareSheet.present returned")
                }
            } catch {
                // Fail loud per project conventions - log the error
                // The user will see that the share sheet didn't open
                print("[Share] Share preparation failed: \(error)")
            }
        }
        print("[Share] Button handler returning")
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
