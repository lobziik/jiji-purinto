//
//  ContentView.swift
//  jiji-purinto
//
//  Created by lobziik on 20.01.2026.
//

import SwiftUI

/// Root content view that switches between screens based on app state.
struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            // State-driven view switching
            switch coordinator.state {
            case .idle:
                HomeScreen(coordinator: coordinator)
                    .transition(.opacity)

            case .selecting:
                // Show HomeScreen as base, with picker as sheet
                HomeScreen(coordinator: coordinator)
                    .transition(.opacity)
                    .sheet(isPresented: .constant(true)) {
                        ImagePickerView(
                            onImageSelected: { image in
                                Task {
                                    // Transition to processing and process the image
                                    coordinator.trySend(.imageSelected(image))
                                    await coordinator.processImage(image)
                                }
                            },
                            onCancel: {
                                coordinator.trySend(.cancelSelection)
                            }
                        )
                        .interactiveDismissDisabled()
                    }

            case .processing:
                ProcessingScreen()
                    .transition(.opacity)

            case .preview(let image, let settings):
                PreviewScreen(
                    coordinator: coordinator,
                    image: coordinator.processedPreview ?? image,
                    settings: settings,
                    onBack: {
                        // Go back to gallery picker
                        coordinator.trySend(.openGallery)
                    }
                )
                .transition(.move(edge: .trailing))

            case .printing(let progress):
                PrintingScreen(progress: progress)
                    .transition(.opacity)

            case .done:
                DoneScreen(coordinator: coordinator)
                    .transition(.scale)

            case .error(let error):
                ErrorScreen(error: error, coordinator: coordinator)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stateIdentifier)
    }

    /// A stable identifier for animation purposes.
    private var stateIdentifier: String {
        switch coordinator.state {
        case .idle: return "idle"
        case .selecting: return "selecting"
        case .processing: return "processing"
        case .preview: return "preview"
        case .printing: return "printing"
        case .done: return "done"
        case .error: return "error"
        }
    }
}

/// Screen shown during printing with progress indicator.
struct PrintingScreen: View {
    let progress: Float

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Placeholder animation area
            Image(systemName: "printer")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: Double(progress))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)

                Text("\(Int(progress * 100))%")
                    .font(.title2.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

/// Screen shown when printing completes.
struct DoneScreen: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main content
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)

                Text("Done!")
                    .font(.largeTitle.weight(.bold))

                Spacer()

                BigButton("Print Another", systemImage: "photo.on.rectangle") {
                    coordinator.trySend(.openGallery)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }

            // Home button - top left
            Button {
                coordinator.trySend(.reset)
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
    }
}

/// Screen shown when an error occurs.
struct ErrorScreen: View {
    let error: AppError
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2.weight(.semibold))

                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            BigButton("Try Again", systemImage: "arrow.counterclockwise") {
                coordinator.trySend(.reset)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
