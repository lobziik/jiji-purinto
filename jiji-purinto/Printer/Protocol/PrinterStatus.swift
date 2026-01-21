//
//  PrinterStatus.swift
//  jiji-purinto
//
//  Simplified printer status for UI display.
//

import Foundation

/// Simplified printer status for UI display.
///
/// Maps the detailed PrinterState to a user-friendly status
/// suitable for display in status indicators.
enum PrinterStatus: Sendable, Equatable {
    /// No printer connected.
    case disconnected

    /// Scanning for available printers.
    case scanning

    /// Connecting to a printer.
    case connecting

    /// Connected and ready to print.
    case ready(printerName: String)

    /// Currently printing.
    case printing(progress: Double)

    /// An error occurred.
    case error(message: String)

    /// Whether the printer is ready to accept print jobs.
    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }

    /// Whether a print operation is in progress.
    var isPrinting: Bool {
        if case .printing = self {
            return true
        }
        return false
    }

    /// Whether the status indicates an error.
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// Short description for UI display.
    var description: String {
        switch self {
        case .disconnected:
            return "Not connected"
        case .scanning:
            return "Scanning..."
        case .connecting:
            return "Connecting..."
        case .ready(let printerName):
            return printerName
        case .printing(let progress):
            return "Printing \(Int(progress * 100))%"
        case .error(let message):
            return message
        }
    }
}
