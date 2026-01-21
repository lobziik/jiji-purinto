//
//  HomeScreen.swift
//  jiji-purinto
//
//  Main home screen with gallery button.
//

import SwiftUI

/// The main home screen where users select an image from the gallery.
///
/// Designed for toddler-friendly interaction with a large central button.
struct HomeScreen: View {
    /// The app coordinator for sending events.
    @ObservedObject var coordinator: AppCoordinator

    /// Whether the debug menu sheet is showing.
    @State private var showDebugSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with debug button (left) and printer status (right)
            HStack {
                // Debug button (only visible when debug menu is enabled)
                if DebugConfig.enableDebugMenu {
                    Button {
                        showDebugSheet = true
                    } label: {
                        Image(systemName: "ladybug")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Debug menu")
                }

                Spacer()

                PrinterStatusView(printerCoordinator: coordinator.printerCoordinator)
                    .padding()
            }

            Spacer()

            // Gallery button (large, central)
            BigIconButton(systemImage: "photo.on.rectangle") {
                do {
                    try coordinator.openGallery()
                } catch {
                    print("[HomeScreen] Failed to open gallery: \(error)")
                }
            }
            .accessibilityLabel("Choose photo from gallery")

            Spacer()
        }
        .sheet(isPresented: $showDebugSheet) {
            DebugMenuSheet(coordinator: coordinator)
        }
    }
}

// MARK: - Previews

#Preview("Home Screen") {
    HomeScreen(coordinator: AppCoordinator())
}
