//
//  FSMContext.swift
//  jiji-purinto
//
//  Context object providing external state for FSM guard conditions.
//

import Foundation

/// Context for FSM transition guards.
///
/// This struct provides external state that the FSM needs to evaluate
/// guard conditions (e.g., whether printing is allowed).
struct FSMContext: Equatable, Sendable {
    /// Whether the printer is connected and ready to print.
    var printerReady: Bool

    /// Creates a new FSM context.
    ///
    /// - Parameter printerReady: Whether the printer is ready. Defaults to `false`.
    init(printerReady: Bool = false) {
        self.printerReady = printerReady
    }

    /// Default context with printer not ready.
    static let `default` = FSMContext(printerReady: false)
}
