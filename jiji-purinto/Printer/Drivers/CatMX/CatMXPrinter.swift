//
//  CatMXPrinter.swift
//  jiji-purinto
//
//  ThermalPrinter implementation for Cat/MX family printers.
//

import Foundation
import CoreBluetooth
import os

/// Logger for CatMX printer operations.
private let printerLogger = Logger(subsystem: "com.jiji-purinto", category: "CatMXPrinter")

/// ThermalPrinter implementation for Cat/MX family thermal printers.
///
/// Handles BLE communication, command sending, and print job execution
/// for Cat/MX printers (MX05-MX11, GB01-03).
final class CatMXPrinter: ThermalPrinter {
    /// The BLE manager for Bluetooth operations.
    private let bleManager: BLEManager

    /// The connected peripheral, if any.
    private var peripheral: BLEPeripheral?

    /// The write characteristic for sending commands.
    private var writeCharacteristic: CBCharacteristic?

    /// The notify characteristic for receiving responses.
    private var notifyCharacteristic: CBCharacteristic?

    /// Active notification stream from the printer.
    private var notificationStream: AsyncStream<Data>?

    /// Device ID of the connected printer.
    private(set) var deviceId: UUID?

    /// Name of the connected printer.
    private(set) var deviceName: String?

    /// Current print quality setting.
    private var quality: CatMXConstants.Quality = .normal

    /// Current energy setting.
    private var energy: UInt8 = 0x60

    /// Re-entrancy guard to detect duplicate print calls.
    private var isPrintingInProgress = false

    /// Whether the printer is currently connected.
    var isConnected: Bool {
        peripheral != nil && writeCharacteristic != nil
    }

    /// Creates a new CatMXPrinter.
    ///
    /// - Parameter bleManager: The BLE manager to use for Bluetooth operations.
    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }

    // MARK: - ThermalPrinter Protocol

    func scan(timeout: TimeInterval) async throws(PrinterError) -> [DiscoveredPrinter] {
        do {
            try await bleManager.waitForReady(timeout: 5.0)
            // Scan without service UUID filter since Cat/MX printers don't advertise it.
            // Filter by name patterns instead.
            return try await bleManager.scan(
                serviceUUID: nil,
                namePatterns: CatMXConstants.namePatterns,
                timeout: timeout
            )
        } catch {
            throw error.asPrinterError
        }
    }

    func scanStream(timeout: TimeInterval) -> AsyncThrowingStream<DiscoveredPrinter, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await bleManager.waitForReady(timeout: 5.0)
                    // Scan without service UUID filter since Cat/MX printers don't advertise it.
                    // Filter by name patterns instead.
                    for try await printer in await bleManager.scanStream(
                        serviceUUID: nil,
                        namePatterns: CatMXConstants.namePatterns,
                        timeout: timeout
                    ) {
                        continuation.yield(printer)
                    }
                    continuation.finish()
                } catch let bleError as BLEError {
                    continuation.finish(throwing: bleError.asPrinterError)
                } catch {
                    continuation.finish(throwing: PrinterError.unexpected(error.localizedDescription))
                }
            }
        }
    }

    func connect(to printer: DiscoveredPrinter) async throws(PrinterError) {
        printerLogger.info("Connecting to printer: \(printer.displayName) (\(printer.id))")
        do {
            // Wait for Bluetooth to be ready (handles cold start race condition)
            try await bleManager.waitForReady(timeout: 5.0)

            // Connect to peripheral
            printerLogger.debug("Establishing BLE connection...")
            let connectedPeripheral = try await bleManager.connect(peripheralId: printer.id, timeout: 10.0)
            self.peripheral = connectedPeripheral
            printerLogger.debug("BLE connection established")

            // Discover services
            printerLogger.debug("Discovering services for UUID: \(CatMXConstants.serviceUUID)")
            _ = try await connectedPeripheral.discoverServices([CatMXConstants.serviceUUID])

            // Get service
            let service = try connectedPeripheral.service(for: CatMXConstants.serviceUUID)
            printerLogger.debug("Found service: \(service.uuid)")

            // Discover characteristics
            printerLogger.debug("Discovering characteristics...")
            _ = try await connectedPeripheral.discoverCharacteristics(
                [CatMXConstants.writeCharUUID, CatMXConstants.notifyCharUUID],
                for: service
            )

            // Get characteristics
            writeCharacteristic = try connectedPeripheral.characteristic(for: CatMXConstants.writeCharUUID)
            notifyCharacteristic = try connectedPeripheral.characteristic(for: CatMXConstants.notifyCharUUID)
            printerLogger.debug("Found write characteristic: \(CatMXConstants.writeCharUUID)")
            printerLogger.debug("Found notify characteristic: \(CatMXConstants.notifyCharUUID)")

            // Store connection info
            deviceId = printer.id
            deviceName = printer.displayName

            // NOTE: Default settings are NOT applied here to avoid race condition.
            // PrinterCoordinator.applySavedSettings() applies saved settings after connection.

            // Subscribe to printer notifications for flow control
            if let notifyChar = notifyCharacteristic {
                printerLogger.debug("Subscribing to notifications on \(CatMXConstants.notifyCharUUID)...")
                notificationStream = try await connectedPeripheral.notifications(for: notifyChar)
                printerLogger.debug("Notification subscription established")
            }

            // Log MTU for debugging transmission issues
            let mtu = connectedPeripheral.peripheral.maximumWriteValueLength(for: .withoutResponse)
            printerLogger.warning("MTU for writeWithoutResponse: \(mtu)")

            printerLogger.info("Successfully connected to \(printer.displayName)")

        } catch let error as BLEError {
            printerLogger.error("Connection failed with BLEError: \(error.localizedDescription)")
            await disconnect()
            throw error.asPrinterError
        } catch {
            printerLogger.error("Connection failed with error: \(error.localizedDescription)")
            await disconnect()
            throw .unexpected(error.localizedDescription)
        }
    }

    func disconnect() async {
        // Disable notifications
        if let notifyChar = notifyCharacteristic, let blePeripheral = peripheral {
            blePeripheral.disableNotifications(for: notifyChar)
        }
        notificationStream = nil

        await bleManager.disconnect()
        peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        deviceId = nil
        deviceName = nil
    }

    func print(bitmap: MonoBitmap, onProgress: @escaping (Double) -> Void) async throws(PrinterError) {
        printerLogger.trace("PRINT CALLED - bitmap: \(bitmap.width)x\(bitmap.height)")

        // Re-entrancy guard to detect duplicate print calls
        guard !isPrintingInProgress else {
            printerLogger.error("PRINT REJECTED - already printing (re-entrancy detected)")
            throw .busy
        }
        isPrintingInProgress = true
        defer { isPrintingInProgress = false }

        guard let characteristic = writeCharacteristic else {
            printerLogger.error("Print failed: writeCharacteristic is nil (not connected)")
            throw .connectionLost
        }

        guard let blePeripheral = peripheral else {
            printerLogger.error("Print failed: peripheral is nil (not connected)")
            throw .connectionLost
        }

        printerLogger.debug("Write characteristic: \(characteristic.uuid)")
        printerLogger.debug("Characteristic properties: \(characteristic.properties.rawValue)")
        printerLogger.debug("Peripheral state: \(blePeripheral.peripheral.state.rawValue)")

        do {
            let totalRows = bitmap.height
            printerLogger.trace("Total rows to print: \(totalRows)")

            var rowsSentCount = 0

            // Send each row with per-row delay to prevent buffer overflow
            for row in 0..<totalRows {
                let rowData = bitmap.row(at: row)
                let lineCmd = CatMXCommands.printLine(rowData: Array(rowData))

                if row == 0 {
                    printerLogger.trace("First row command (\(lineCmd.count) bytes)")
                }

                // Log transmitted data (debug level for visibility)
                let hexData = lineCmd.map { String(format: "%02X", $0) }.joined(separator: " ")
                printerLogger.debug("TX row \(row): \(lineCmd.count)B [\(hexData)]")

                try await sendCommand(lineCmd, to: characteristic)
                rowsSentCount += 1

                // No per-row delay needed - BLEPeripheral.waitForWriteReady() provides
                // flow control by waiting when CoreBluetooth's buffer is full

                // Report progress every 10 rows
                if row % 10 == 0 || row == totalRows - 1 {
                    let progress = Double(row + 1) / Double(totalRows)
                    onProgress(progress)
                }

                // Log every 50 rows
                if row % 50 == 0 {
                    printerLogger.trace("Print progress: row \(row)/\(totalRows)")
                }
            }

            printerLogger.trace("PRINT LOOP DONE - sent \(rowsSentCount) rows out of \(totalRows)")

            // Feed paper at end (no endPrint command needed for Cat/MX protocol)
            let feedLines = CatMXConstants.defaultFeedLines
            let feedCmd = CatMXCommands.feedPaper(lines: feedLines)
            printerLogger.trace("Sending FEED_PAPER: \(feedLines) lines")
            try await sendCommand(feedCmd, to: characteristic)

            printerLogger.trace("Print job completed successfully")

        } catch let error as BLEError {
            printerLogger.error("Print failed with BLEError: \(error.localizedDescription)")
            throw error.asPrinterError
        } catch let error as PrinterError {
            printerLogger.error("Print failed with PrinterError: \(error.localizedDescription)")
            throw error
        } catch {
            printerLogger.error("Print failed with unexpected error: \(error.localizedDescription)")
            throw .unexpected(error.localizedDescription)
        }
    }

    // MARK: - Configuration

    /// Sets the print quality.
    ///
    /// - Parameter quality: The quality level to use.
    /// - Throws: `PrinterError` if not connected or write fails.
    func setQuality(_ quality: CatMXConstants.Quality) async throws(PrinterError) {
        guard let characteristic = writeCharacteristic else {
            printerLogger.error("setQuality failed: not connected (writeCharacteristic is nil)")
            throw .connectionLost
        }

        let qualityName: String
        switch quality {
        case .light: qualityName = "light"
        case .normal: qualityName = "normal"
        case .dark: qualityName = "dark"
        }

        printerLogger.info("setQuality: setting quality to \(qualityName) (rawValue: 0x\(String(format: "%02X", quality.rawValue)))")

        do {
            let cmd = CatMXCommands.setQuality(quality)
            let hexCmd = cmd.map { String(format: "%02X", $0) }.joined(separator: " ")
            printerLogger.debug("setQuality: command bytes [\(hexCmd)]")

            try await sendCommand(cmd, to: characteristic)
            self.quality = quality
            printerLogger.info("setQuality: SUCCESS - quality set to \(qualityName)")
        } catch let error as BLEError {
            printerLogger.error("setQuality: FAILED with BLEError: \(error.localizedDescription)")
            throw error.asPrinterError
        } catch {
            printerLogger.error("setQuality: FAILED with error: \(error.localizedDescription)")
            throw .unexpected(error.localizedDescription)
        }
    }

    /// Sets the print energy (heat level).
    ///
    /// - Parameter energy: Energy level (0x00-0xFF, typically 0x60-0x80).
    /// - Throws: `PrinterError` if not connected or write fails.
    func setEnergy(_ energy: UInt8) async throws(PrinterError) {
        guard let characteristic = writeCharacteristic else {
            printerLogger.error("setEnergy failed: not connected (writeCharacteristic is nil)")
            throw .connectionLost
        }

        // Calculate percentage for logging (0x00=0%, 0xFF=100%)
        let percentApprox = Int(Double(energy) / 255.0 * 100.0)
        printerLogger.info("setEnergy: setting energy to 0x\(String(format: "%02X", energy)) (~\(percentApprox)%)")

        do {
            let cmd = CatMXCommands.setEnergy(energy)
            let hexCmd = cmd.map { String(format: "%02X", $0) }.joined(separator: " ")
            printerLogger.debug("setEnergy: command bytes [\(hexCmd)]")

            try await sendCommand(cmd, to: characteristic)
            self.energy = energy
            printerLogger.info("setEnergy: SUCCESS - energy set to 0x\(String(format: "%02X", energy))")
        } catch let error as BLEError {
            printerLogger.error("setEnergy: FAILED with BLEError: \(error.localizedDescription)")
            throw error.asPrinterError
        } catch {
            printerLogger.error("setEnergy: FAILED with error: \(error.localizedDescription)")
            throw .unexpected(error.localizedDescription)
        }
    }

    /// Feeds paper by specified number of lines.
    ///
    /// - Parameter lines: Number of blank lines to feed.
    /// - Throws: `PrinterError` if not connected or write fails.
    func feedPaper(lines: UInt16) async throws(PrinterError) {
        guard let characteristic = writeCharacteristic else {
            throw .connectionLost
        }

        do {
            let cmd = CatMXCommands.feedPaper(lines: lines)
            try await sendCommand(cmd, to: characteristic)
        } catch let error as BLEError {
            throw error.asPrinterError
        } catch {
            throw .unexpected(error.localizedDescription)
        }
    }

    /// Applies the current energy settings.
    ///
    /// Must be called after setEnergy() to activate the configuration.
    ///
    /// - Throws: `PrinterError` if not connected or write fails.
    func applyEnergy() async throws(PrinterError) {
        guard let characteristic = writeCharacteristic else {
            printerLogger.error("applyEnergy failed: not connected (writeCharacteristic is nil)")
            throw .connectionLost
        }

        printerLogger.info("applyEnergy: applying energy settings (activating configuration)")

        do {
            let cmd = CatMXCommands.applyEnergy()
            let hexCmd = cmd.map { String(format: "%02X", $0) }.joined(separator: " ")
            printerLogger.debug("applyEnergy: command bytes [\(hexCmd)]")

            try await sendCommand(cmd, to: characteristic)
            printerLogger.info("applyEnergy: SUCCESS - energy settings applied")
        } catch let error as BLEError {
            printerLogger.error("applyEnergy: FAILED with BLEError: \(error.localizedDescription)")
            throw error.asPrinterError
        } catch {
            printerLogger.error("applyEnergy: FAILED with error: \(error.localizedDescription)")
            throw .unexpected(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    /// Sends a command to the printer.
    ///
    /// Commands must be sent as complete packets. CoreBluetooth handles
    /// MTU negotiation automatically - manual chunking breaks the protocol.
    ///
    /// Uses `.withoutResponse` since the printer's write characteristic doesn't
    /// support acknowledged writes. Flow control is handled by `BLEPeripheral`
    /// via `canSendWriteWithoutResponse` and `peripheralIsReady` callback to
    /// prevent buffer overflow and silent data loss.
    ///
    /// - Parameters:
    ///   - command: The command data to send.
    ///   - characteristic: The characteristic to write to.
    /// - Throws: `BLEError` if write fails.
    private func sendCommand(_ command: Data, to characteristic: CBCharacteristic) async throws {
        guard let blePeripheral = peripheral else {
            printerLogger.error("sendCommand failed: peripheral is nil")
            throw BLEError.notConnected
        }

        printerLogger.trace("Sending command (\(command.count) bytes)")

        // Send command as a single write - CoreBluetooth handles MTU negotiation
        // DO NOT split commands manually - it corrupts the packet structure
        // Flow control is handled by BLEPeripheral.waitForWriteReady()
        try await blePeripheral.write(data: command, to: characteristic, type: .withoutResponse)
    }
}
