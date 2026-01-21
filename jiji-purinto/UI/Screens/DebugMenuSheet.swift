//
//  DebugMenuSheet.swift
//  jiji-purinto
//
//  Debug menu sheet for printer diagnostics and test patterns.
//

import SwiftUI

/// Sheet for debug test pattern printing.
///
/// Only visible when `DebugConfig.enableDebugMenu` is true.
/// Provides test patterns for diagnosing printer issues.
struct DebugMenuSheet: View {
    /// The app coordinator for printing test patterns.
    @ObservedObject var coordinator: AppCoordinator

    /// Dismiss action for the sheet.
    @Environment(\.dismiss) private var dismiss

    /// Error message to display if printing fails.
    @State private var errorMessage: String?

    /// Whether an error alert is showing.
    @State private var showingError = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ForEach(TestPatternType.allCases) { pattern in
                        Button {
                            Task {
                                do {
                                    dismiss()
                                    try await coordinator.printTestPattern(pattern)
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pattern.rawValue)
                                Text(pattern.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!coordinator.printerReady)
                    }
                } header: {
                    Label("Test Patterns", systemImage: "ladybug")
                } footer: {
                    Text("Print test patterns to diagnose printer issues. Requires connected printer.")
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Print Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Previews

#Preview("Debug Menu Sheet") {
    DebugMenuSheet(coordinator: AppCoordinator())
}
