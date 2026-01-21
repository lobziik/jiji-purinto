//
//  PrinterState.swift
//  jiji-purinto
//
//  Printer connection FSM states.
//

import Foundation

/// Represents all possible states of the printer connection FSM.
///
/// The printer progresses through these states during its lifecycle:
/// - Start disconnected
/// - Scan for available printers
/// - Connect to a selected printer
/// - Ready to print or printing
/// - Handle errors and recovery
enum PrinterState: Sendable, Equatable {
    /// No printer connected. Initial state and state after disconnect.
    case disconnected

    /// Actively scanning for available printers.
    case scanning

    /// Connecting to a specific printer.
    case connecting(deviceId: UUID)

    /// Connected and ready to accept print jobs.
    case ready(deviceId: UUID, deviceName: String)

    /// Currently executing a print job.
    case busy(deviceId: UUID)

    /// An error occurred. Requires explicit reset to recover.
    case error(PrinterError)

    /// The device ID of the currently connected or connecting printer, if any.
    var deviceId: UUID? {
        switch self {
        case .disconnected, .scanning, .error:
            return nil
        case .connecting(let deviceId):
            return deviceId
        case .ready(let deviceId, _):
            return deviceId
        case .busy(let deviceId):
            return deviceId
        }
    }

    /// The name of the connected printer, if available.
    var deviceName: String? {
        switch self {
        case .ready(_, let deviceName):
            return deviceName
        default:
            return nil
        }
    }

    /// Whether the printer is in a state where it can accept print jobs.
    var canPrint: Bool {
        if case .ready = self {
            return true
        }
        return false
    }

    /// Whether the printer is currently connected (ready or busy).
    var isConnected: Bool {
        switch self {
        case .ready, .busy:
            return true
        default:
            return false
        }
    }

    /// Whether we can start scanning from this state.
    var canStartScan: Bool {
        switch self {
        case .disconnected:
            return true
        default:
            return false
        }
    }

    /// Converts to a simplified PrinterStatus for UI display.
    var status: PrinterStatus {
        switch self {
        case .disconnected:
            return .disconnected
        case .scanning:
            return .scanning
        case .connecting:
            return .connecting
        case .ready(_, let deviceName):
            return .ready(printerName: deviceName)
        case .busy:
            return .printing(progress: 0)
        case .error(let printerError):
            return .error(message: printerError.localizedDescription)
        }
    }
}
