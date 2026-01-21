//
//  PrinterStatusView.swift
//  jiji-purinto
//
//  Printer status indicator with scan sheet for connecting to printers.
//

import SwiftUI

/// Printer status indicator that shows connection state and allows scanning.
///
/// Tap to show the scan sheet when disconnected or in error state.
/// Shows different colors and animations based on status:
/// - Red: disconnected/error (tap to scan)
/// - Yellow pulsing: scanning/connecting
/// - Green: ready (shows printer name)
/// - Blue pulsing: printing
struct PrinterStatusView: View {
    /// The printer coordinator for state and actions.
    @ObservedObject var printerCoordinator: PrinterCoordinator

    /// Whether the scan sheet is shown.
    @State private var showingScanSheet = false

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "printer")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)

                StatusDot(status: printerCoordinator.status)

                if let name = statusText {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingScanSheet) {
            PrinterScanSheet(printerCoordinator: printerCoordinator)
        }
    }

    /// Text to show next to the status indicator.
    private var statusText: String? {
        switch printerCoordinator.status {
        case .ready(let printerName):
            return printerName
        case .printing(let progress):
            return "\(Int(progress * 100))%"
        case .error:
            return "Error"
        default:
            return nil
        }
    }

    /// Handles tap on the status indicator.
    private func handleTap() {
        switch printerCoordinator.status {
        case .disconnected, .error:
            showingScanSheet = true
        case .ready:
            // Could show printer info or disconnect option
            showingScanSheet = true
        default:
            break
        }
    }
}

/// Animated status dot showing printer connection state.
struct StatusDot: View {
    /// The current printer status.
    let status: PrinterStatus

    /// Animation state for pulsing effect.
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(shouldPulse ? pulsingAnimation : .default, value: isPulsing)
            .onAppear {
                if shouldPulse {
                    isPulsing = true
                }
            }
            .onChange(of: shouldPulse) { newValue in
                isPulsing = newValue
            }
    }

    /// Color for the status dot.
    private var statusColor: Color {
        switch status {
        case .disconnected:
            return .red
        case .scanning, .connecting:
            return .yellow
        case .ready:
            return .green
        case .printing:
            return .blue
        case .error:
            return .red
        }
    }

    /// Whether the dot should pulse.
    private var shouldPulse: Bool {
        switch status {
        case .scanning, .connecting, .printing:
            return true
        default:
            return false
        }
    }

    /// Animation for pulsing effect.
    private var pulsingAnimation: Animation {
        Animation.easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
    }
}

/// Sheet for scanning and connecting to printers.
struct PrinterScanSheet: View {
    /// The printer coordinator for state and actions.
    @ObservedObject var printerCoordinator: PrinterCoordinator

    /// Environment to dismiss the sheet.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if printerCoordinator.isScanning {
                    scanningView
                } else if printerCoordinator.discoveredPrinters.isEmpty {
                    emptyStateView
                } else {
                    printerListView
                }
            }
            .navigationTitle("Printers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        printerCoordinator.cancelScan()
                        dismiss()
                    }
                }

                if printerCoordinator.isReady {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Disconnect") {
                            Task {
                                await printerCoordinator.disconnect()
                                dismiss()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// View shown while scanning.
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning for printers...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// View shown when no printers are found.
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "printer.dotmatrix")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No printers found")
                .font(.headline)

            Text("Make sure your printer is turned on and nearby")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Scan Again") {
                Task {
                    await printerCoordinator.startScan()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !printerCoordinator.isReady {
                Task {
                    await printerCoordinator.startScan()
                }
            }
        }
    }

    /// View showing discovered printers.
    private var printerListView: some View {
        List {
            if printerCoordinator.isReady {
                Section("Connected") {
                    if let name = printerCoordinator.printerName {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(name)
                        }
                    }
                }
            }

            Section("Available Printers") {
                ForEach(printerCoordinator.discoveredPrinters) { printer in
                    Button {
                        Task {
                            await printerCoordinator.connect(to: printer)
                            if printerCoordinator.isReady {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(printer.displayName)
                                    .foregroundColor(.primary)
                                Text("Signal: \(signalStrength(rssi: printer.rssi))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if case .connecting = printerCoordinator.status {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!canConnect)
                }
            }

            Section {
                Button("Scan Again") {
                    Task {
                        await printerCoordinator.startScan()
                    }
                }
                .disabled(printerCoordinator.isScanning)
            }
        }
    }

    /// Whether we can connect to a printer.
    private var canConnect: Bool {
        switch printerCoordinator.status {
        case .disconnected, .scanning:
            return true
        default:
            return false
        }
    }

    /// Converts RSSI to a human-readable signal strength.
    private func signalStrength(rssi: Int) -> String {
        switch rssi {
        case -50...0:
            return "Excellent"
        case -60..<(-50):
            return "Good"
        case -70..<(-60):
            return "Fair"
        default:
            return "Weak"
        }
    }
}

// MARK: - Previews

#Preview("Status - Disconnected") {
    PrinterStatusView(printerCoordinator: PrinterCoordinator())
        .padding()
}
