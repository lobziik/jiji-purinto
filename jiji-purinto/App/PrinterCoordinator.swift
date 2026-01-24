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

    /// Current printer hardware settings.
    @Published private(set) var printerSettings: PrinterSettings = .default

    // MARK: - Private

    private let fsm = PrinterFSM()
    private let storage = PrinterStorage()
    private let settingsStorage = PrinterSettingsStorage()
    private let bleManager: BLEManager
    private var printer: ThermalPrinter?

    /// Device name to restore after transitioning from busy to ready.
    private var connectedDeviceName: String?

    // MARK: - Auto-Reconnection

    /// Configuration for auto-reconnection behavior.
    private enum ReconnectConfig {
        /// Maximum number of reconnection attempts before giving up.
        static let maxAttempts = 3
        /// Delay between reconnection attempts in seconds.
        static let retryDelay: TimeInterval = 2.0
    }

    /// Device ID of the last connected printer for reconnection.
    private var lastConnectedDeviceId: UUID?

    /// Device name of the last connected printer for reconnection.
    private var lastConnectedDeviceName: String?

    /// Current number of reconnection attempts.
    private var reconnectAttempts = 0

    /// Whether auto-reconnection is currently in progress.
    @Published private(set) var isReconnecting: Bool = false

    /// Callback invoked when print is interrupted by connection loss.
    ///
    /// This allows the AppCoordinator to transition to an error state when
    /// a print operation is interrupted by an unexpected disconnection.
    var onPrintInterrupted: ((PrinterError) -> Void)?

    // MARK: - Initialization

    init() {
        self.bleManager = BLEManager()
        self.printer = CatMXPrinter(bleManager: bleManager)
        self.printerSettings = settingsStorage.settings
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

        coordinatorLogger.warning("Printer connection lost unexpectedly from state: \(String(describing: self.state))")

        // Capture whether printing was in progress before state change
        let wasInBusy = isPrinting

        // Capture device info before transitioning to error state
        let deviceId = lastConnectedDeviceId
        let deviceName = lastConnectedDeviceName

        do {
            try send(.connectionLost)
        } catch {
            coordinatorLogger.error("Failed to send connectionLost event: \(error.localizedDescription)")
        }

        // Notify about interrupted print
        if wasInBusy {
            coordinatorLogger.warning("Print operation interrupted by connection loss")
            onPrintInterrupted?(.connectionLost)
        }

        // Start background reconnection if we have device info
        if let deviceId = deviceId, let deviceName = deviceName {
            Task {
                await attemptAutoReconnect(deviceId: deviceId, deviceName: deviceName)
            }
        }
    }

    // MARK: - FSM Event Handling

    /// Sends an event to the printer FSM.
    ///
    /// - Parameter event: The event to process.
    /// - Throws: `FSMError` if the transition is invalid.
    func send(_ event: PrinterEvent) throws {
        let fromState = state
        let newState = try fsm.transition(from: state, event: event)
        coordinatorLogger.info("PrinterFSM: \(String(describing: fromState)) --[\(String(describing: event))]--> \(String(describing: newState))")

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

    /// Starts scanning for printers with reactive streaming.
    ///
    /// Discovered printers appear one-by-one as they are found,
    /// rather than waiting for the full timeout.
    ///
    /// - Parameter timeout: Scan timeout in seconds.
    func startScan(timeout: TimeInterval = 10.0) async {
        // Determine which event to use based on current state
        let event: PrinterEvent
        if case .scanning = state {
            // Already scanning, use restartScan for self-loop transition
            event = .restartScan
            coordinatorLogger.debug("Restarting scan from scanning state")
        } else if case .error = state {
            // Reset from error state first, then start scan
            coordinatorLogger.debug("Resetting from error state before scanning")
            do {
                try send(.reset)
            } catch {
                coordinatorLogger.error("Failed to reset from error state: \(error.localizedDescription)")
                return
            }
            event = .startScan
        } else if case .connecting = state {
            // Cancel connection attempt and start scan
            coordinatorLogger.debug("Cancelling connection attempt to start scanning")
            do {
                try send(.connectFailed(.connectionFailed(reason: "Cancelled by user")))
                try send(.reset)
            } catch {
                coordinatorLogger.error("Failed to cancel connection: \(error.localizedDescription)")
                return
            }
            event = .startScan
        } else {
            guard state.canStartScan else {
                coordinatorLogger.warning("Cannot start scan from state: \(String(describing: self.state))")
                return
            }
            event = .startScan
        }

        do {
            try send(event)
            discoveredPrinters = []  // Clear previous results for fresh scan

            guard let printer = printer else {
                try send(.scanTimeout)
                return
            }

            // Use streaming scan for reactive updates
            coordinatorLogger.debug("Starting streaming scan with \(timeout)s timeout")
            for try await discovered in printer.scanStream(timeout: timeout) {
                // Only add if not already in the list
                if !discoveredPrinters.contains(where: { $0.id == discovered.id }) {
                    discoveredPrinters.append(discovered)
                    // Sort by signal strength (higher RSSI = better signal)
                    discoveredPrinters.sort { $0.rssi > $1.rssi }
                    coordinatorLogger.debug("Discovered: \(discovered.displayName) (RSSI: \(discovered.rssi))")
                }
            }

            isScanning = false  // BLE scan finished, show results
            coordinatorLogger.debug("Scan completed. Found \(self.discoveredPrinters.count) printer(s)")

            if discoveredPrinters.isEmpty {
                try send(.scanTimeout)
            }
            // Stay in scanning state until user connects or cancels

        } catch let error as PrinterError {
            isScanning = false
            do {
                try send(.connectFailed(error))
            } catch {
                coordinatorLogger.error("Failed to send connectFailed event: \(error.localizedDescription)")
            }
        } catch {
            isScanning = false
            do {
                try send(.connectFailed(.unexpected(error.localizedDescription)))
            } catch {
                coordinatorLogger.error("Failed to send connectFailed event: \(error.localizedDescription)")
            }
        }
    }

    /// Cancels an ongoing scan.
    func cancelScan() {
        coordinatorLogger.debug("Cancelling scan from state: \(String(describing: self.state))")
        do {
            try send(.cancelScan)
        } catch {
            coordinatorLogger.warning("Failed to cancel scan: \(error.localizedDescription)")
        }
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

            // Save for auto-reconnect (both storage and local state)
            storage.saveLastPrinter(id: discoveredPrinter.id, name: discoveredPrinter.displayName)
            lastConnectedDeviceId = discoveredPrinter.id
            lastConnectedDeviceName = discoveredPrinter.displayName
            reconnectAttempts = 0  // Reset attempts on successful connection

            try send(.connectSuccess(
                deviceId: discoveredPrinter.id,
                deviceName: discoveredPrinter.displayName
            ))

            // Apply saved printer settings after successful connection
            await applySavedSettings()

        } catch let error as PrinterError {
            try? send(.connectFailed(error))
        } catch {
            try? send(.connectFailed(.unexpected(error.localizedDescription)))
        }
    }

    /// Disconnects from the current printer.
    ///
    /// An intentional disconnect cancels any auto-reconnection attempts
    /// and clears the saved device info.
    func disconnect() async {
        guard state.isConnected else { return }

        coordinatorLogger.debug("Disconnecting (intentional) from state: \(String(describing: self.state))")

        // Cancel auto-reconnect since this is an intentional disconnect
        cancelAutoReconnect()

        await printer?.disconnect()
        do {
            try send(.disconnect)
        } catch {
            coordinatorLogger.warning("Failed to send disconnect event: \(error.localizedDescription)")
        }
    }

    /// Attempts to reconnect to the last connected printer.
    ///
    /// This is called on app launch if a printer was previously connected.
    func reconnectToLast() async {
        guard let lastId = storage.lastPrinterId,
              let lastName = storage.lastPrinterName else {
            coordinatorLogger.debug("No last printer stored, skipping reconnect")
            return
        }

        coordinatorLogger.info("Attempting to reconnect to last printer: \(lastName) (\(lastId))")

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
            coordinatorLogger.info("Successfully reconnected to \(lastName)")

        } catch {
            coordinatorLogger.warning("Failed to reconnect to last printer: \(error.localizedDescription)")
            // Clear saved printer on failed reconnect
            storage.clearLastPrinter()
            do {
                try send(.connectFailed(.connectionFailed(reason: "Could not reconnect to last printer")))
            } catch {
                coordinatorLogger.error("Failed to send connectFailed event: \(error.localizedDescription)")
            }
        }
    }

    /// Prints a bitmap image.
    ///
    /// - Parameters:
    ///   - bitmap: The 1-bit bitmap to print.
    ///   - onProgress: Optional callback for progress updates (0.0 to 1.0).
    /// - Throws: `PrinterError` if printing fails.
    func print(bitmap: MonoBitmap, onProgress: ((Double) -> Void)? = nil) async throws(PrinterError) {
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
                    onProgress?(progress)
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
        coordinatorLogger.debug("Resetting from state: \(String(describing: self.state))")
        do {
            try send(.reset)
        } catch {
            coordinatorLogger.warning("Failed to reset: \(error.localizedDescription)")
        }
        printProgress = 0
    }

    // MARK: - Auto-Reconnection

    /// Forces coordinator to disconnected state, bypassing FSM if needed.
    ///
    /// This is a recovery mechanism used when FSM transitions fail and the
    /// coordinator gets stuck in an intermediate state. It should only be
    /// used as a last resort when proper FSM transitions are not possible.
    private func forceDisconnectedState() {
        if case .disconnected = state {
            status = .disconnected
            return
        }

        // Try FSM transition first
        if case .error = state {
            do {
                try send(.reset)
                return
            } catch {
                coordinatorLogger.error("FSM reset failed, forcing state: \(error.localizedDescription)")
            }
        }

        // Force state if FSM transition failed or state wasn't error
        coordinatorLogger.warning("Forcing state to disconnected (was: \(String(describing: self.state)))")
        state = .disconnected
        status = .disconnected
        isPrinting = false
        isScanning = false
    }

    /// Attempts to automatically reconnect to a printer after connection loss.
    ///
    /// This method runs in the background and attempts to reconnect up to
    /// `ReconnectConfig.maxAttempts` times with delays between attempts.
    ///
    /// - Parameters:
    ///   - deviceId: The UUID of the device to reconnect to.
    ///   - deviceName: The name of the device (for logging and status display).
    private func attemptAutoReconnect(deviceId: UUID, deviceName: String) async {
        guard !isReconnecting else {
            coordinatorLogger.debug("Already reconnecting, skipping duplicate attempt")
            return
        }

        isReconnecting = true
        reconnectAttempts = 0

        coordinatorLogger.info("Starting auto-reconnection to \(deviceName) (\(deviceId))")

        while reconnectAttempts < ReconnectConfig.maxAttempts {
            reconnectAttempts += 1
            coordinatorLogger.info("Reconnection attempt \(self.reconnectAttempts)/\(ReconnectConfig.maxAttempts)")

            // Update status to show reconnection progress
            status = .reconnecting(attempt: reconnectAttempts, maxAttempts: ReconnectConfig.maxAttempts)

            // Reset from error state to allow reconnection
            do {
                // Ensure we're in a state that can accept .reconnect event
                if case .error = state {
                    try send(.reset)
                } else if case .connecting = state {
                    // State may be stuck in connecting from previous failed attempt
                    // Force recovery to disconnected state
                    coordinatorLogger.warning("Stuck in connecting state, forcing recovery")
                    forceDisconnectedState()
                }

                // Ensure we're in disconnected state before attempting reconnect
                if case .disconnected = state {
                    // Already in correct state, proceed
                } else {
                    coordinatorLogger.warning("Cannot reconnect from state: \(String(describing: self.state)), forcing recovery")
                    forceDisconnectedState()
                }

                try send(.reconnect(deviceId: deviceId))

                // Create a discovered printer from stored info
                let savedPrinter = DiscoveredPrinter(id: deviceId, name: deviceName, rssi: 0)

                guard let printer = printer else {
                    coordinatorLogger.error("Printer driver not initialized during reconnection")
                    throw PrinterError.unexpected("Printer driver not initialized")
                }

                try await printer.connect(to: savedPrinter)

                // Success - update state
                try send(.connectSuccess(deviceId: deviceId, deviceName: deviceName))
                coordinatorLogger.info("Auto-reconnection successful on attempt \(self.reconnectAttempts)")

                isReconnecting = false
                reconnectAttempts = 0
                return

            } catch {
                coordinatorLogger.warning("Reconnection attempt \(self.reconnectAttempts) failed: \(error.localizedDescription)")

                // Transition back to error state for next attempt
                if case .connecting = state {
                    do {
                        try send(.connectFailed(.connectionFailed(reason: "Reconnection attempt \(reconnectAttempts) failed")))
                    } catch {
                        coordinatorLogger.error("Failed to send connectFailed, forcing state recovery: \(error.localizedDescription)")
                        // Force recovery if FSM transition failed
                        forceDisconnectedState()
                    }
                }

                // Wait before next attempt (unless this was the last attempt)
                if reconnectAttempts < ReconnectConfig.maxAttempts {
                    coordinatorLogger.debug("Waiting \(ReconnectConfig.retryDelay)s before next attempt")
                    try? await Task.sleep(nanoseconds: UInt64(ReconnectConfig.retryDelay * 1_000_000_000))
                }
            }
        }

        // All attempts failed
        coordinatorLogger.warning("Auto-reconnection failed after \(ReconnectConfig.maxAttempts) attempts")
        isReconnecting = false
        reconnectAttempts = 0

        // Ensure we're in disconnected state using forced recovery
        forceDisconnectedState()
    }

    /// Cancels any ongoing auto-reconnection attempts.
    ///
    /// Called when user explicitly disconnects to prevent auto-reconnect.
    private func cancelAutoReconnect() {
        if isReconnecting {
            coordinatorLogger.debug("Cancelling auto-reconnection")
        }
        isReconnecting = false
        reconnectAttempts = 0
        lastConnectedDeviceId = nil
        lastConnectedDeviceName = nil
    }

    // MARK: - Printer Settings

    /// Applies saved settings to the connected printer.
    ///
    /// Called automatically after successful connection.
    /// Logs but does not throw errors to avoid blocking reconnection.
    private func applySavedSettings() async {
        guard let catMXPrinter = printer as? CatMXPrinter else {
            coordinatorLogger.warning("applySavedSettings: printer driver not available (cast to CatMXPrinter failed)")
            return
        }

        let qualityCatMX = printerSettings.quality.catMXQuality
        let energyByte = printerSettings.energyByte

        coordinatorLogger.info("applySavedSettings: START - quality=\(self.printerSettings.quality.rawValue) (catMX: 0x\(String(format: "%02X", qualityCatMX.rawValue))), energyPercent=\(self.printerSettings.energyPercent)% (byte: 0x\(String(format: "%02X", energyByte)))")

        do {
            coordinatorLogger.debug("applySavedSettings: calling setQuality(\(self.printerSettings.quality.rawValue))...")
            try await catMXPrinter.setQuality(qualityCatMX)
            coordinatorLogger.debug("applySavedSettings: setQuality completed")

            coordinatorLogger.debug("applySavedSettings: calling setEnergy(0x\(String(format: "%02X", energyByte)))...")
            try await catMXPrinter.setEnergy(energyByte)
            coordinatorLogger.debug("applySavedSettings: setEnergy completed")

            coordinatorLogger.debug("applySavedSettings: calling applyEnergy()...")
            try await catMXPrinter.applyEnergy()
            coordinatorLogger.debug("applySavedSettings: applyEnergy completed")

            coordinatorLogger.info("applySavedSettings: SUCCESS - all printer settings applied")
        } catch {
            coordinatorLogger.error("applySavedSettings: FAILED - \(error.localizedDescription)")
        }
    }

    /// Applies new settings to the connected printer and persists them.
    ///
    /// - Parameter settings: The new settings to apply.
    /// - Throws: `PrinterError` if the printer is not connected or the command fails.
    func applySettings(_ settings: PrinterSettings) async throws(PrinterError) {
        guard let catMXPrinter = printer as? CatMXPrinter else {
            coordinatorLogger.error("applySettings: printer driver not available (cast to CatMXPrinter failed)")
            throw .unexpected("Printer driver not available")
        }

        guard state.isConnected else {
            coordinatorLogger.error("applySettings: printer not connected (state: \(String(describing: self.state)))")
            throw .connectionLost
        }

        let qualityCatMX = settings.quality.catMXQuality
        let energyByte = settings.energyByte

        coordinatorLogger.info("applySettings: START - quality=\(settings.quality.rawValue) (catMX: 0x\(String(format: "%02X", qualityCatMX.rawValue))), energyPercent=\(settings.energyPercent)% (byte: 0x\(String(format: "%02X", energyByte)))")

        coordinatorLogger.debug("applySettings: calling setQuality(\(settings.quality.rawValue))...")
        try await catMXPrinter.setQuality(qualityCatMX)
        coordinatorLogger.debug("applySettings: setQuality completed")

        coordinatorLogger.debug("applySettings: calling setEnergy(0x\(String(format: "%02X", energyByte)))...")
        try await catMXPrinter.setEnergy(energyByte)
        coordinatorLogger.debug("applySettings: setEnergy completed")

        coordinatorLogger.debug("applySettings: calling applyEnergy()...")
        try await catMXPrinter.applyEnergy()
        coordinatorLogger.debug("applySettings: applyEnergy completed")

        settingsStorage.save(settings)
        printerSettings = settings
        coordinatorLogger.info("applySettings: SUCCESS - settings applied and saved (quality=\(settings.quality.rawValue), energy=\(settings.energyPercent)%)")
    }

    /// Updates settings locally and persists them without sending to printer.
    ///
    /// Use this method for immediate UI updates when the user changes settings.
    /// The actual printer commands are sent via `applySettings`.
    ///
    /// - Parameter settings: The new settings to save.
    func updateSettings(_ settings: PrinterSettings) {
        let oldQuality = printerSettings.quality.rawValue
        let oldEnergy = printerSettings.energyPercent

        printerSettings = settings
        settingsStorage.save(settings)

        coordinatorLogger.info("updateSettings: quality \(oldQuality) -> \(settings.quality.rawValue), energy \(oldEnergy)% -> \(settings.energyPercent)% (local only, not sent to printer)")
    }
}

// MARK: - PrinterError Extension

extension PrinterError {
    /// Printer is not connected or not ready.
    static let printerNotReady = PrinterError.connectionLost
}
