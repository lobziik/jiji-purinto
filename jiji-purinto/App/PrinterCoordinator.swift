//
//  PrinterCoordinator.swift
//  jiji-purinto
//
//  Coordinates printer state and connects PrinterFSM to the app.
//

import SwiftUI
import Combine
import os

/// Logger for printer coordination.
private let coordinatorLogger = Logger(subsystem: "com.jiji-purinto", category: "PrinterCoordinator")

/// Coordinates printer connection and print operations.
///
/// This class manages the printer FSM, BLE communication, and provides
/// a reactive interface for SwiftUI views.
@MainActor
final class PrinterCoordinator: ObservableObject {
    // MARK: - Published State

    /// Current printer state.
    @Published private(set) var state: PrinterState = .disconnected

    /// Simplified printer status for UI display.
    @Published private(set) var status: PrinterStatus = .disconnected

    /// Discovered printers from the last scan.
    @Published private(set) var discoveredPrinters: [DiscoveredPrinter] = []

    /// Current print progress (0.0 to 1.0).
    @Published private(set) var printProgress: Double = 0

    /// Whether a scan is currently in progress.
    @Published private(set) var isScanning: Bool = false

    /// Whether a print operation is in progress.
    @Published private(set) var isPrinting: Bool = false

    // MARK: - Private

    private let fsm = PrinterFSM()
    private let storage = PrinterStorage()
    private let bleManager: BLEManager
    private var printer: ThermalPrinter?

    /// Device name to restore after transitioning from busy to ready.
    private var connectedDeviceName: String?

    // MARK: - Initialization

    init() {
        self.bleManager = BLEManager()
        self.printer = CatMXPrinter(bleManager: bleManager)
        setupDisconnectHandler()
    }

    /// Sets up the disconnect handler for unexpected disconnections.
    private func setupDisconnectHandler() {
        Task {
            await bleManager.setOnDisconnect { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.handleConnectionLost()
                }
            }
        }
    }

    /// Handles unexpected connection loss.
    private func handleConnectionLost() {
        guard state.isConnected else { return }

        do {
            try send(.connectionLost)
        } catch {
            // Already in an incompatible state, ignore
        }
    }

    // MARK: - FSM Event Handling

    /// Sends an event to the printer FSM.
    ///
    /// - Parameter event: The event to process.
    /// - Throws: `FSMError` if the transition is invalid.
    func send(_ event: PrinterEvent) throws {
        let newState = try fsm.transition(from: state, event: event)

        // Handle special state transitions
        switch newState {
        case .ready(_, let deviceName):
            connectedDeviceName = deviceName
        case .busy:
            break
        case .disconnected, .scanning, .connecting, .error:
            connectedDeviceName = nil
        }

        state = newState
        updateStatus()
    }

    /// Updates the simplified status based on current state.
    private func updateStatus() {
        switch state {
        case .disconnected:
            status = .disconnected
            isScanning = false
            isPrinting = false
        case .scanning:
            status = .scanning
            isScanning = true
        case .connecting:
            status = .connecting
            isScanning = false
        case .ready(_, let deviceName):
            status = .ready(printerName: deviceName)
            isPrinting = false
        case .busy:
            status = .printing(progress: printProgress)
            isPrinting = true
        case .error(let error):
            status = .error(message: error.localizedDescription)
            isScanning = false
            isPrinting = false
        }
    }

    // MARK: - Public API

    /// Whether the printer is ready to accept print jobs.
    var isReady: Bool {
        state.canPrint
    }

    /// The connected printer's name, if connected.
    var printerName: String? {
        state.deviceName
    }

    /// Starts scanning for printers.
    ///
    /// - Parameter timeout: Scan timeout in seconds.
    func startScan(timeout: TimeInterval = 10.0) async {
        guard state.canStartScan else { return }

        do {
            try send(.startScan)

            guard let printer = printer else {
                try send(.scanTimeout)
                return
            }

            let printers = try await printer.scan(timeout: timeout)
            discoveredPrinters = printers
            isScanning = false  // BLE scan finished, show results

            if printers.isEmpty {
                try send(.scanTimeout)
            }
            // Stay in scanning state until user connects or cancels

        } catch let error as PrinterError {
            try? send(.connectFailed(error))
        } catch {
            try? send(.connectFailed(.unexpected(error.localizedDescription)))
        }
    }

    /// Cancels an ongoing scan.
    func cancelScan() {
        try? send(.cancelScan)
        discoveredPrinters = []
    }

    /// Connects to a discovered printer.
    ///
    /// - Parameter printer: The printer to connect to.
    func connect(to discoveredPrinter: DiscoveredPrinter) async {
        do {
            try send(.connect(printer: discoveredPrinter))

            guard let printer = printer else {
                try send(.connectFailed(.unexpected("Printer driver not initialized")))
                return
            }

            try await printer.connect(to: discoveredPrinter)

            // Save for auto-reconnect
            storage.saveLastPrinter(id: discoveredPrinter.id, name: discoveredPrinter.displayName)

            try send(.connectSuccess(
                deviceId: discoveredPrinter.id,
                deviceName: discoveredPrinter.displayName
            ))

        } catch let error as PrinterError {
            try? send(.connectFailed(error))
        } catch {
            try? send(.connectFailed(.unexpected(error.localizedDescription)))
        }
    }

    /// Disconnects from the current printer.
    func disconnect() async {
        guard state.isConnected else { return }

        await printer?.disconnect()
        try? send(.disconnect)
    }

    /// Attempts to reconnect to the last connected printer.
    ///
    /// This is called on app launch if a printer was previously connected.
    func reconnectToLast() async {
        guard let lastId = storage.lastPrinterId,
              let lastName = storage.lastPrinterName else {
            return
        }

        do {
            try send(.reconnect(deviceId: lastId))

            // Create a discovered printer from stored info
            let savedPrinter = DiscoveredPrinter(id: lastId, name: lastName, rssi: 0)

            guard let printer = printer else {
                try send(.connectFailed(.unexpected("Printer driver not initialized")))
                return
            }

            try await printer.connect(to: savedPrinter)

            try send(.connectSuccess(deviceId: lastId, deviceName: lastName))

        } catch {
            // Clear saved printer on failed reconnect
            storage.clearLastPrinter()
            try? send(.connectFailed(.connectionFailed(reason: "Could not reconnect to last printer")))
        }
    }

    /// Prints a bitmap image.
    ///
    /// - Parameter bitmap: The 1-bit bitmap to print.
    /// - Throws: `PrinterError` if printing fails.
    func print(bitmap: MonoBitmap) async throws(PrinterError) {
        coordinatorLogger.info("Print requested: \(bitmap.width)x\(bitmap.height) bitmap")
        coordinatorLogger.debug("Current state: \(String(describing: self.state))")
        coordinatorLogger.debug("canPrint: \(self.state.canPrint)")

        guard state.canPrint else {
            coordinatorLogger.error("Print rejected: state.canPrint is false")
            throw .printerNotReady
        }

        guard let printer = printer else {
            coordinatorLogger.error("Print rejected: printer is nil")
            throw .unexpected("Printer driver not initialized")
        }

        coordinatorLogger.debug("Printer driver available, starting print...")

        do {
            try send(.printStart)
            printProgress = 0
            coordinatorLogger.debug("FSM transitioned to printing state")

            try await printer.print(bitmap: bitmap) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.printProgress = progress
                    self?.updateStatus()
                }
            }

            coordinatorLogger.info("Print completed successfully")
            printProgress = 1.0
            try send(.printComplete)

            // Restore device name after print completes
            if let deviceName = connectedDeviceName,
               case .ready(let deviceId, _) = state {
                // Re-apply the correct device name
                state = .ready(deviceId: deviceId, deviceName: deviceName)
                updateStatus()
            }

        } catch let error as PrinterError {
            coordinatorLogger.error("Print failed with PrinterError: \(error.localizedDescription)")
            try? send(.printFailed(error))
            throw error
        } catch {
            coordinatorLogger.error("Print failed with unexpected error: \(error.localizedDescription)")
            let printerError = PrinterError.unexpected(error.localizedDescription)
            try? send(.printFailed(printerError))
            throw printerError
        }
    }

    /// Resets from error state.
    func reset() {
        try? send(.reset)
        printProgress = 0
    }
}

// MARK: - PrinterError Extension

extension PrinterError {
    /// Printer is not connected or not ready.
    static let printerNotReady = PrinterError.connectionLost
}
