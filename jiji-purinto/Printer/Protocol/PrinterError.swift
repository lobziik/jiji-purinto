//
//  PrinterError.swift
//  jiji-purinto
//
//  Printer-specific error types for connection and printing failures.
//

import Foundation

/// Errors that can occur during printer operations.
///
/// These errors represent failures in the printer subsystem including
/// Bluetooth connectivity issues and print job failures.
enum PrinterError: Error, Sendable, Equatable {
    /// Bluetooth is not available on this device.
    case bluetoothUnavailable

    /// Bluetooth is powered off.
    case bluetoothPoweredOff

    /// Bluetooth permission was denied by the user.
    case bluetoothUnauthorized

    /// Scan timed out without finding any printers.
    case scanTimeout

    /// Failed to connect to the printer.
    case connectionFailed(reason: String)

    /// Connection to the printer was lost unexpectedly.
    case connectionLost

    /// Required Bluetooth service was not found on the device.
    case serviceNotFound

    /// Required Bluetooth characteristic was not found.
    case characteristicNotFound

    /// Failed to write data to the printer.
    case writeFailed(reason: String)

    /// Print job failed.
    case printFailed(reason: String)

    /// Printer reported an error status.
    case printerError(status: UInt8)

    /// Printer is out of paper.
    case outOfPaper

    /// Printer is overheated and needs to cool down.
    case overheated

    /// Printer battery is too low.
    case lowBattery

    /// Operation timed out waiting for printer response.
    case timeout

    /// Unexpected error.
    case unexpected(String)
}

extension PrinterError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available on this device"
        case .bluetoothPoweredOff:
            return "Please turn on Bluetooth to connect to the printer"
        case .bluetoothUnauthorized:
            return "Bluetooth permission is required. Please enable it in Settings"
        case .scanTimeout:
            return "No printers found. Make sure your printer is turned on and nearby"
        case .connectionFailed(let reason):
            return "Failed to connect to printer: \(reason)"
        case .connectionLost:
            return "Connection to printer was lost"
        case .serviceNotFound:
            return "Printer service not found. This may not be a compatible printer"
        case .characteristicNotFound:
            return "Printer communication channel not found"
        case .writeFailed(let reason):
            return "Failed to send data to printer: \(reason)"
        case .printFailed(let reason):
            return "Print failed: \(reason)"
        case .printerError(let status):
            return "Printer reported error (status: \(status))"
        case .outOfPaper:
            return "Printer is out of paper"
        case .overheated:
            return "Printer is overheated. Please wait for it to cool down"
        case .lowBattery:
            return "Printer battery is too low. Please charge the printer"
        case .timeout:
            return "Printer did not respond in time"
        case .unexpected(let message):
            return "Unexpected printer error: \(message)"
        }
    }
}
