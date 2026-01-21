//
//  AppFSM.swift
//  jiji-purinto
//
//  Finite State Machine for application flow.
//

import UIKit

/// Finite State Machine for the main application flow.
///
/// This FSM is pure and deterministic: given the same state, event, and context,
/// it always produces the same result. All invalid transitions throw `FSMError`.
///
/// ## State Flow
/// ```
/// idle -> selecting -> processing -> preview -> printing -> done
///                                                       \-> error
/// ```
///
/// ## Usage
/// ```swift
/// let fsm = AppFSM()
/// let nextState = try fsm.transition(
///     from: .idle,
///     event: .openGallery,
///     context: FSMContext()
/// )
/// // nextState == .selecting(source: .gallery)
/// ```
struct AppFSM {
    /// Computes the next state given the current state and an event.
    ///
    /// - Parameters:
    ///   - state: The current state.
    ///   - event: The event to process.
    ///   - context: External context for guard conditions.
    /// - Returns: The new state after the transition.
    /// - Throws: `FSMError.invalidTransition` if the transition is not allowed,
    ///           or `FSMError.guardFailed` if a guard condition is not met.
    func transition(
        from state: AppState,
        event: AppEvent,
        context: FSMContext = .default
    ) throws -> AppState {
        switch (state, event) {
        // MARK: - From idle
        case (.idle, .openGallery):
            return .selecting(source: .gallery)

        case (.idle, .print):
            // Allow printing from idle for debug test patterns
            guard context.printerReady else {
                throw FSMError.guardFailed(reason: "Printer is not ready")
            }
            return .printing(progress: 0)

        // MARK: - From selecting
        case (.selecting, .imageSelected):
            return .processing

        case (.selecting, .imageSelectionFailed(let error)):
            return .error(error)

        case (.selecting, .cancelSelection):
            return .idle

        // MARK: - From processing
        case (.processing, .processingComplete(let image)):
            return .preview(image: image, settings: .default)

        case (.processing, .processingFailed(let error)):
            return .error(error)

        // MARK: - From preview
        case (.preview(let image, _), .settingsChanged(let newSettings)):
            return .preview(image: image, settings: newSettings)

        case (.preview, .print):
            guard context.printerReady else {
                throw FSMError.guardFailed(reason: "Printer is not ready")
            }
            return .printing(progress: 0)

        case (.preview, .openGallery):
            return .selecting(source: .gallery)

        case (.preview, .reset):
            return .idle

        // MARK: - From printing
        case (.printing, .printProgress(let progress)):
            return .printing(progress: progress)

        case (.printing, .printSuccess):
            return .done

        case (.printing, .printFailed(let error)):
            return .error(error)

        // MARK: - From done
        case (.done, .reset):
            return .idle

        case (.done, .openGallery):
            return .selecting(source: .gallery)

        // MARK: - From error
        case (.error, .reset):
            return .idle

        // MARK: - Invalid transitions
        default:
            throw FSMError.invalidTransition(
                from: state.debugDescription,
                event: event.debugDescription
            )
        }
    }
}
