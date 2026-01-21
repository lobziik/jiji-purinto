//
//  CatMXConstants.swift
//  jiji-purinto
//
//  Constants for Cat/MX thermal printer protocol.
//

import CoreBluetooth

/// Constants for Cat/MX family thermal printers (MX05-MX11, GB01-03).
///
/// These printers use a proprietary BLE GATT protocol with specific
/// service and characteristic UUIDs.
enum CatMXConstants {
    // MARK: - BLE UUIDs

    /// Service UUID for Cat/MX printers.
    static let serviceUUID = CBUUID(string: "AE30")

    /// Name prefixes for discovering Cat/MX printers during BLE scan.
    ///
    /// Cat/MX printers don't advertise their service UUID, so we filter by
    /// device name instead. Common prefixes: MX05-MX11, GB01-03, Cat variants.
    static let namePatterns = ["MX", "GB", "Cat"]

    /// Characteristic UUID for receiving notifications from printer.
    /// Note: Despite naming conventions, MX11 uses AE02 for notify.
    static let notifyCharUUID = CBUUID(string: "AE02")

    /// Characteristic UUID for writing commands to printer.
    /// Note: Despite naming conventions, MX11 uses AE01 for write.
    static let writeCharUUID = CBUUID(string: "AE01")

    // MARK: - Protocol Constants

    /// Command prefix for all Cat/MX commands.
    static let commandPrefix: [UInt8] = [0x51, 0x78]

    /// Default MTU (Maximum Transmission Unit) for BLE writes.
    static let defaultMTU = 20

    /// Optimal chunk size for print data (accounts for command overhead).
    static let printDataChunkSize = 112

    /// Print width in pixels (fixed for Cat/MX printers).
    static let printWidth = 384

    /// Print width in bytes (1 bit per pixel).
    static let printWidthBytes = printWidth / 8  // 48 bytes

    // MARK: - Command Identifiers

    /// Command IDs for Cat/MX protocol.
    enum Command: UInt8 {
        /// Get device information.
        case getDeviceInfo = 0xA8

        /// Set print quality/density.
        case setQuality = 0xA4

        /// Set print energy/heat level.
        case setEnergy = 0xAF

        /// Feed paper by specified amount.
        case feedPaper = 0xA1

        /// Start a print job.
        case startPrint = 0xA6

        /// Print a line of data.
        case printLine = 0xA2

        /// End a print job.
        case endPrint = 0xA3

        /// Get printer status.
        case getStatus = 0xA7
    }

    // MARK: - Quality Settings

    /// Print quality/density levels.
    enum Quality: UInt8 {
        /// Light print (faster, less ink).
        case light = 0x31
        /// Normal print quality.
        case normal = 0x32
        /// Dark print (slower, more ink).
        case dark = 0x33
    }

    // MARK: - Status Bytes

    /// Printer status response bits.
    enum StatusBit: UInt8 {
        /// Printer is ready.
        case ready = 0x00
        /// Paper is out or jammed.
        case paperError = 0x01
        /// Printer is overheated.
        case overheat = 0x02
        /// Battery is low.
        case lowBattery = 0x04
    }
}
