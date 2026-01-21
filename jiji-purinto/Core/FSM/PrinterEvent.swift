//
//  PrinterEvent.swift
//  jiji-purinto
//
//  Printer FSM events that trigger state transitions.
//

import Foundation

/// Events that trigger printer state transitions.
///
/// Each event represents a user action or system occurrence
/// that can cause the printer FSM to change state.
enum PrinterEvent: Sendable, Equatable {
    // MARK: - Scanning Events

    /// Start scanning for available printers.
    case startScan

    /// Restart scanning while already in scanning state (e.g., "Scan Again" button).
    case restartScan

    /// Cancel an ongoing scan.
    case cancelScan

    /// Scan completed without finding printers or timed out.
    case scanTimeout

    // MARK: - Connection Events

    /// Connect to a discovered printer.
    case connect(printer: DiscoveredPrinter)

    /// Connection to printer succeeded.
    case connectSuccess(deviceId: UUID, deviceName: String)

    /// Connection to printer failed.
    case connectFailed(PrinterError)

    /// Disconnect from the current printer.
    case disconnect

    /// Connection to printer was lost unexpectedly.
    case connectionLost

    // MARK: - Print Events

    /// Start a print job.
    case printStart

    /// Print job completed successfully.
    case printComplete

    /// Print job failed.
    case printFailed(PrinterError)

    // MARK: - Recovery Events

    /// Reset from error state to disconnected.
    case reset

    /// Attempt to reconnect after connection loss.
    case reconnect(deviceId: UUID)
}

extension PrinterEvent: CustomStringConvertible {
    var description: String {
        switch self {
        case .startScan:
            return "startScan"
        case .restartScan:
            return "restartScan"
        case .cancelScan:
            return "cancelScan"
        case .scanTimeout:
            return "scanTimeout"
        case .connect(let printer):
            return "connect(\(printer.displayName))"
        case .connectSuccess(_, let deviceName):
            return "connectSuccess(\(deviceName))"
        case .connectFailed(let error):
            return "connectFailed(\(error))"
        case .disconnect:
            return "disconnect"
        case .connectionLost:
            return "connectionLost"
        case .printStart:
            return "printStart"
        case .printComplete:
            return "printComplete"
        case .printFailed(let error):
            return "printFailed(\(error))"
        case .reset:
            return "reset"
        case .reconnect(let deviceId):
            return "reconnect(\(deviceId))"
        }
    }
}
