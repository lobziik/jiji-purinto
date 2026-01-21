//
//  CatMXCommands.swift
//  jiji-purinto
//
//  Command builders for Cat/MX thermal printer protocol.
//

import Foundation

/// Builds command packets for Cat/MX thermal printers.
///
/// All commands follow the format:
/// `[0x51, 0x78] [cmd] [00] [length_low] [length_high] [data...] [crc] [0xFF]`
///
/// - CRC is CRC8 with polynomial 0x07, calculated only on payload data
/// - Length is little-endian (low byte first)
///
/// Based on the TypeScript reference implementation (@opuu/cat-printer).
enum CatMXCommands {

    // MARK: - Configuration Commands

    /// Builds a set quality command.
    ///
    /// - Parameter quality: The print quality level.
    /// - Returns: Command data to send to printer.
    static func setQuality(_ quality: CatMXConstants.Quality) -> Data {
        buildCommand(.setQuality, data: [quality.rawValue])
    }

    /// Builds a set energy command.
    ///
    /// Controls how much heat is applied to the print head.
    /// Higher values produce darker prints but may overheat.
    ///
    /// - Parameter energy: Energy level (0x00-0xFF, typically 0x60-0x80).
    /// - Returns: Command data to send to printer.
    static func setEnergy(_ energy: UInt8) -> Data {
        buildCommand(.setEnergy, data: [energy])
    }

    /// Sets print speed.
    ///
    /// - Parameter speed: Speed value (typically 32).
    /// - Returns: Command data to send to printer.
    static func setSpeed(_ speed: UInt8) -> Data {
        buildCommand(.setSpeed, data: [speed])
    }

    /// Applies energy settings.
    ///
    /// Must be called after setEnergy() to activate the energy configuration.
    ///
    /// - Returns: Command data to send to printer.
    static func applyEnergy() -> Data {
        buildCommand(.applyEnergy, data: [0x01])
    }

    // MARK: - Paper Feed Commands

    /// Builds a feed paper command.
    ///
    /// - Parameter lines: Number of blank lines to feed (typically 20-40).
    /// - Returns: Command data to send to printer.
    static func feedPaper(lines: UInt16) -> Data {
        let lowByte = UInt8(lines & 0xFF)
        let highByte = UInt8((lines >> 8) & 0xFF)
        return buildCommand(.feedPaper, data: [lowByte, highByte])
    }

    /// Builds a retract paper command.
    ///
    /// - Parameter lines: Number of lines to retract.
    /// - Returns: Command data to send to printer.
    static func retract(lines: UInt16) -> Data {
        let lowByte = UInt8(lines & 0xFF)
        let highByte = UInt8((lines >> 8) & 0xFF)
        return buildCommand(.retract, data: [lowByte, highByte])
    }

    // MARK: - Print Commands

    /// Builds a print line command.
    ///
    /// Each line should be exactly 48 bytes (384 pixels at 1 bit per pixel).
    /// Bits are MSB first (leftmost pixel is bit 7 of first byte).
    ///
    /// - Parameter rowData: Raw bitmap data for one print line (48 bytes).
    /// - Returns: Command data to send to printer.
    static func printLine(rowData: [UInt8]) -> Data {
        buildCommand(.printLine, data: rowData)
    }

    // MARK: - Status Commands

    /// Builds a get status command.
    ///
    /// - Returns: Command data to send to printer.
    static func getStatus() -> Data {
        buildCommand(.getStatus, data: [])
    }

    /// Builds a get device info command.
    ///
    /// - Returns: Command data to send to printer.
    static func getDeviceInfo() -> Data {
        buildCommand(.getDeviceInfo, data: [])
    }

    // MARK: - Command Building

    /// Builds a complete command packet.
    ///
    /// Command format:
    /// `[0x51, 0x78] [cmd] [00] [length_low] [length_high] [data...] [crc] [0xFF]`
    ///
    /// - Parameters:
    ///   - command: The command identifier.
    ///   - data: Command payload data.
    /// - Returns: Complete command packet as Data.
    static func buildCommand(_ command: CatMXConstants.Command, data: [UInt8]) -> Data {
        var packet: [UInt8] = CatMXConstants.commandPrefix

        // Command byte
        packet.append(command.rawValue)

        // Reserved byte (always 0x00)
        packet.append(0x00)

        // Data length (little-endian)
        let length = UInt16(data.count)
        packet.append(UInt8(length & 0xFF))
        packet.append(UInt8((length >> 8) & 0xFF))

        // Payload data
        packet.append(contentsOf: data)

        // Calculate CRC8 only on payload data
        packet.append(crc8(data))

        // End marker
        packet.append(0xFF)

        return Data(packet)
    }

    /// Parses a status response from the printer.
    ///
    /// - Parameter data: Response data from the printer.
    /// - Returns: The status byte, or nil if response is invalid.
    static func parseStatusResponse(_ data: Data) -> UInt8? {
        // Status response format: [prefix] [cmd] [00] [len_lo] [len_hi] [status] [crc] [0xFF]
        guard data.count >= 8 else { return nil }

        // Verify it's a status response
        let bytes = Array(data)
        guard bytes[0] == 0x51, bytes[1] == 0x78 else { return nil }
        guard bytes[2] == CatMXConstants.Command.getStatus.rawValue else { return nil }

        // Get status byte (at position 6)
        return bytes[6]
    }

    /// Checks if a status byte indicates an error.
    ///
    /// - Parameter status: The status byte from printer.
    /// - Returns: A PrinterError if status indicates an error, nil otherwise.
    static func errorFromStatus(_ status: UInt8) -> PrinterError? {
        if status & CatMXConstants.StatusBit.paperError.rawValue != 0 {
            return .outOfPaper
        }
        if status & CatMXConstants.StatusBit.overheat.rawValue != 0 {
            return .overheated
        }
        if status & CatMXConstants.StatusBit.lowBattery.rawValue != 0 {
            return .lowBattery
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Calculates CRC8 checksum with polynomial 0x07.
    ///
    /// This algorithm matches the TypeScript reference implementation.
    ///
    /// - Parameter data: The data bytes to calculate CRC for.
    /// - Returns: The calculated CRC8 checksum.
    private static func crc8(_ data: [UInt8]) -> UInt8 {
        var crc: UInt8 = 0
        for byte in data {
            crc ^= byte
            for _ in 0..<8 {
                if (crc & 0x80) != 0 {
                    crc = (crc << 1) ^ 0x07
                } else {
                    crc = crc << 1
                }
            }
        }
        return crc
    }
}
