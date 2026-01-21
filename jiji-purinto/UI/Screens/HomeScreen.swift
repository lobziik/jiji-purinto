//
//  HomeScreen.swift
//  jiji-purinto
//
//  Main home screen with camera and gallery buttons.
//

import SwiftUI

/// The main home screen where users select an image source.
///
/// Designed for toddler-friendly interaction with large buttons.
struct HomeScreen: View {
    /// The app coordinator for sending events.
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            // Printer status indicator (top right)
            HStack {
                Spacer()
                PrinterStatusView(printerCoordinator: coordinator.printerCoordinator)
                    .padding()
            }

            Spacer()

            // Camera button (large, central)
            BigIconButton(systemImage: "camera") {
                do {
                    try coordinator.openCamera()
                } catch {
                    print("[HomeScreen] Failed to open camera: \(error)")
                }
            }
            .accessibilityLabel("Take a photo")

            Spacer()

            // Gallery button
            BigButton("Gallery", systemImage: "photo.on.rectangle") {
                do {
                    try coordinator.openGallery()
                } catch {
                    print("[HomeScreen] Failed to open gallery: \(error)")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .accessibilityLabel("Choose from gallery")
        }
    }
}

// MARK: - Previews

#Preview("Home Screen") {
    HomeScreen(coordinator: AppCoordinator())
}
