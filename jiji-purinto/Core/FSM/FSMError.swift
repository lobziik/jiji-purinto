//
//  FSMError.swift
//  jiji-purinto
//
//  Errors thrown by the finite state machine.
//

import Foundation

/// Errors thrown when FSM transitions fail.
///
/// The FSM follows FAIL FAST principle - any invalid transition throws immediately
/// rather than silently ignoring the event.
enum FSMError: Error, Equatable {
    /// The requested transition is not allowed from the current state.
    ///
    /// - Parameters:
    ///   - from: The current state.
    ///   - event: The event that was attempted.
    case invalidTransition(from: String, event: String)

    /// A guard condition prevented the transition.
    ///
    /// - Parameter reason: Human-readable explanation of why the guard failed.
    case guardFailed(reason: String)
}

extension FSMError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let event):
            return "Invalid transition: cannot handle '\(event)' from state '\(from)'"
        case .guardFailed(let reason):
            return "Guard failed: \(reason)"
        }
    }
}
