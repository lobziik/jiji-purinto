//
//  PrinterFSM.swift
//  jiji-purinto
//
//  Pure, deterministic state machine for printer connection management.
//

import Foundation

/// Pure, deterministic finite state machine for printer connection management.
///
/// This FSM manages the printer connection lifecycle, handling scanning,
/// connecting, printing, and error recovery. All transitions are explicit
/// and invalid transitions throw FSMError.
///
/// ## State Transition Table
///
/// | From | Event | To |
/// |------|-------|-----|
/// | disconnected | startScan | scanning |
/// | disconnected | reconnect | connecting |
/// | scanning | restartScan | scanning |
/// | scanning | connect | connecting |
/// | scanning | cancelScan | disconnected |
/// | scanning | scanTimeout | disconnected |
/// | connecting | connectSuccess | ready |
/// | connecting | connectFailed | error |
/// | connecting | connectionLost | error |
/// | ready | printStart | busy |
/// | ready | disconnect | disconnected |
/// | ready | connectionLost | error |
/// | busy | printComplete | ready |
/// | busy | printFailed | error |
/// | busy | connectionLost | error |
/// | error | reset | disconnected |
///
struct PrinterFSM: Sendable {

    /// Computes the next state given the current state and an event.
    ///
    /// This function is pure and deterministic: the same state and event
    /// always produce the same result. Invalid transitions throw FSMError.
    ///
    /// - Parameters:
    ///   - state: The current printer state.
    ///   - event: The event that occurred.
    /// - Returns: The new state after processing the event.
    /// - Throws: `FSMError.invalidTransition` if the transition is not allowed.
    func transition(from state: PrinterState, event: PrinterEvent) throws(FSMError) -> PrinterState {
        switch (state, event) {

        // MARK: - From disconnected

        case (.disconnected, .startScan):
            return .scanning

        case (.disconnected, .reconnect(let deviceId)):
            return .connecting(deviceId: deviceId)

        // MARK: - From scanning

        case (.scanning, .restartScan):
            return .scanning

        case (.scanning, .connect(let printer)):
            return .connecting(deviceId: printer.id)

        case (.scanning, .cancelScan):
            return .disconnected

        case (.scanning, .scanTimeout):
            return .disconnected

        // MARK: - From connecting

        case (.connecting, .connectSuccess(let deviceId, let deviceName)):
            return .ready(deviceId: deviceId, deviceName: deviceName)

        case (.connecting, .connectFailed(let error)):
            return .error(error)

        case (.connecting, .connectionLost):
            return .error(.connectionLost)

        // MARK: - From ready

        case (.ready(let deviceId, _), .printStart):
            return .busy(deviceId: deviceId)

        case (.ready, .disconnect):
            return .disconnected

        case (.ready, .connectionLost):
            return .error(.connectionLost)

        // MARK: - From busy

        case (.busy(let deviceId), .printComplete):
            // Extract device name from the previous ready state would require context
            // For now, we use a placeholder - the coordinator will track the actual name
            return .ready(deviceId: deviceId, deviceName: "Printer")

        case (.busy, .printFailed(let error)):
            return .error(error)

        case (.busy, .connectionLost):
            return .error(.connectionLost)

        // MARK: - From error

        case (.error, .reset):
            return .disconnected

        // MARK: - Invalid transitions

        default:
            throw .invalidTransition(from: "\(state)", event: "\(event)")
        }
    }
}
