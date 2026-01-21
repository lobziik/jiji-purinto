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

    /// Device ID of the connected printer.
    private(set) var deviceId: UUID?

    /// Name of the connected printer.
    private(set) var deviceName: String?

    /// Current print quality setting.
    private var quality: CatMXConstants.Quality = .normal

    /// Current energy setting.
    private var energy: UInt8 = 0x60

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

            // Set default quality and energy
            printerLogger.debug("Setting default quality and energy...")
            try await setQuality(.normal)
            try await setEnergy(0x60)
            try await applyEnergy()

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
        await bleManager.disconnect()
        peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        deviceId = nil
        deviceName = nil
    }

    func print(bitmap: MonoBitmap, onProgress: @escaping (Double) -> Void) async throws(PrinterError) {
        printerLogger.info("Starting print job: \(bitmap.width)x\(bitmap.height) pixels")

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
            printerLogger.info("Total rows to print: \(totalRows)")

            // Send each row (no startPrint command needed for Cat/MX protocol)
            for row in 0..<totalRows {
                let rowData = bitmap.row(at: row)
                let lineCmd = CatMXCommands.printLine(rowData: Array(rowData))

                if row == 0 {
                    printerLogger.debug("First row command (\(lineCmd.count) bytes): \(lineCmd.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " "))...")
                }

                // Send row data in chunks if needed
                try await sendCommand(lineCmd, to: characteristic)

                // Report progress after each row
                let progress = Double(row + 1) / Double(totalRows)
                onProgress(progress)

                // Log every 50 rows
                if row % 50 == 0 {
                    printerLogger.debug("Print progress: row \(row)/\(totalRows) (\(Int(progress * 100))%)")
                }

                // Small delay to prevent overwhelming the printer
                if row % 10 == 0 {
                    try await Task.sleep(nanoseconds: 5_000_000) // 5ms
                }
            }

            printerLogger.debug("All \(totalRows) rows sent")

            // Feed paper at end (no endPrint command needed for Cat/MX protocol)
            let feedCmd = CatMXCommands.feedPaper(lines: 40)
            printerLogger.debug("Sending FEED_PAPER command (\(feedCmd.count) bytes): \(feedCmd.map { String(format: "%02X", $0) }.joined(separator: " "))")
            try await sendCommand(feedCmd, to: characteristic)
            printerLogger.debug("FEED_PAPER command sent successfully")

            printerLogger.info("Print job completed successfully")

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
            throw .connectionLost
        }

        do {
            let cmd = CatMXCommands.setQuality(quality)
            try await sendCommand(cmd, to: characteristic)
            self.quality = quality
        } catch let error as BLEError {
            throw error.asPrinterError
        } catch {
            throw .unexpected(error.localizedDescription)
        }
    }

    /// Sets the print energy (heat level).
    ///
    /// - Parameter energy: Energy level (0x00-0xFF, typically 0x60-0x80).
    /// - Throws: `PrinterError` if not connected or write fails.
    func setEnergy(_ energy: UInt8) async throws(PrinterError) {
        guard let characteristic = writeCharacteristic else {
            throw .connectionLost
        }

        do {
            let cmd = CatMXCommands.setEnergy(energy)
            try await sendCommand(cmd, to: characteristic)
            self.energy = energy
        } catch let error as BLEError {
            throw error.asPrinterError
        } catch {
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
            throw .connectionLost
        }

        do {
            let cmd = CatMXCommands.applyEnergy()
            try await sendCommand(cmd, to: characteristic)
        } catch let error as BLEError {
            throw error.asPrinterError
        } catch {
            throw .unexpected(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    /// Sends a command to the printer, chunking if necessary.
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

        let mtu = CatMXConstants.defaultMTU

        if command.count <= mtu {
            // Single chunk
            printerLogger.trace("Writing single chunk (\(command.count) bytes) to characteristic")
            try await blePeripheral.write(data: command, to: characteristic, type: .withoutResponse)
        } else {
            // Split into chunks
            printerLogger.trace("Splitting command (\(command.count) bytes) into chunks of \(mtu) bytes")
            var offset = 0
            var chunkCount = 0
            while offset < command.count {
                let chunkSize = min(mtu, command.count - offset)
                let chunk = command[offset..<(offset + chunkSize)]
                try await blePeripheral.write(data: Data(chunk), to: characteristic, type: .withoutResponse)
                offset += chunkSize
                chunkCount += 1

                // Small delay between chunks
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
            printerLogger.trace("Sent \(chunkCount) chunks")
        }
    }
}
