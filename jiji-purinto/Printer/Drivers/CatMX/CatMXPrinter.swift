//
//  CatMXPrinter.swift
//  jiji-purinto
//
//  ThermalPrinter implementation for Cat/MX family printers.
//

import Foundation
import CoreBluetooth

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
            return try await bleManager.scan(serviceUUID: CatMXConstants.serviceUUID, timeout: timeout)
        } catch {
            throw error.asPrinterError
        }
    }

    func connect(to printer: DiscoveredPrinter) async throws(PrinterError) {
        do {
            // Connect to peripheral
            let connectedPeripheral = try await bleManager.connect(peripheralId: printer.id, timeout: 10.0)
            self.peripheral = connectedPeripheral

            // Discover services
            _ = try await connectedPeripheral.discoverServices([CatMXConstants.serviceUUID])

            // Get service
            let service = try connectedPeripheral.service(for: CatMXConstants.serviceUUID)

            // Discover characteristics
            _ = try await connectedPeripheral.discoverCharacteristics(
                [CatMXConstants.writeCharUUID, CatMXConstants.notifyCharUUID],
                for: service
            )

            // Get characteristics
            writeCharacteristic = try connectedPeripheral.characteristic(for: CatMXConstants.writeCharUUID)
            notifyCharacteristic = try connectedPeripheral.characteristic(for: CatMXConstants.notifyCharUUID)

            // Store connection info
            deviceId = printer.id
            deviceName = printer.displayName

            // Set default quality and energy
            try await setQuality(.normal)
            try await setEnergy(0x60)

        } catch let error as BLEError {
            await disconnect()
            throw error.asPrinterError
        } catch {
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
        guard let characteristic = writeCharacteristic else {
            throw .connectionLost
        }

        do {
            let totalRows = bitmap.height

            // Send start print command
            let startCmd = CatMXCommands.startPrint(totalRows: UInt16(totalRows))
            try await sendCommand(startCmd, to: characteristic)

            // Send each row
            for row in 0..<totalRows {
                let rowData = bitmap.row(at: row)
                let lineCmd = CatMXCommands.printLine(rowData: Array(rowData))

                // Send row data in chunks if needed
                try await sendCommand(lineCmd, to: characteristic)

                // Report progress after each row
                let progress = Double(row + 1) / Double(totalRows)
                onProgress(progress)

                // Small delay to prevent overwhelming the printer
                if row % 10 == 0 {
                    try await Task.sleep(nanoseconds: 5_000_000) // 5ms
                }
            }

            // Send end print command
            let endCmd = CatMXCommands.endPrint()
            try await sendCommand(endCmd, to: characteristic)

            // Feed paper
            let feedCmd = CatMXCommands.feedPaper(lines: 20)
            try await sendCommand(feedCmd, to: characteristic)

        } catch let error as BLEError {
            throw error.asPrinterError
        } catch let error as PrinterError {
            throw error
        } catch {
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

    // MARK: - Private Methods

    /// Sends a command to the printer, chunking if necessary.
    ///
    /// - Parameters:
    ///   - command: The command data to send.
    ///   - characteristic: The characteristic to write to.
    /// - Throws: `BLEError` if write fails.
    private func sendCommand(_ command: Data, to characteristic: CBCharacteristic) async throws {
        guard let blePeripheral = peripheral else {
            throw BLEError.notConnected
        }

        let mtu = CatMXConstants.defaultMTU

        if command.count <= mtu {
            // Single chunk
            try await blePeripheral.write(data: command, to: characteristic, type: .withoutResponse)
        } else {
            // Split into chunks
            var offset = 0
            while offset < command.count {
                let chunkSize = min(mtu, command.count - offset)
                let chunk = command[offset..<(offset + chunkSize)]
                try await blePeripheral.write(data: Data(chunk), to: characteristic, type: .withoutResponse)
                offset += chunkSize

                // Small delay between chunks
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
    }
}
