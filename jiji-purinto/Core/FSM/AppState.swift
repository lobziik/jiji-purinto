//
//  AppState.swift
//  jiji-purinto
//
//  Application state for the FSM.
//

import UIKit

/// Application states for the main flow FSM.
///
/// The app follows a linear flow: idle -> selecting -> processing -> preview -> printing -> done.
/// Error can be reached from most states and allows recovery back to idle.
///
/// - Note: This enum is marked `@unchecked Sendable` because UIImage is not Sendable.
///   For v0.2, consider migrating to image ID + repository pattern for proper concurrency safety.
enum AppState: Equatable, @unchecked Sendable {
    /// Initial state. App is ready for user to select an image source.
    case idle

    /// User is selecting an image from the specified source.
    case selecting(source: ImageSource)

    /// Image is being processed (resized, dithered, etc.).
    case processing

    /// Image is processed and ready for preview/printing.
    ///
    /// - Parameters:
    ///   - image: The processed preview image.
    ///   - settings: Current image processing settings.
    case preview(image: UIImage, settings: ImageSettings)

    /// Print job is in progress.
    ///
    /// - Parameter progress: Print progress from 0.0 to 1.0.
    case printing(progress: Float)

    /// Print completed successfully.
    case done

    /// An error occurred. User can reset to idle.
    case error(AppError)
}

// MARK: - State Queries

extension AppState {
    /// Whether the user can select a new image source from this state.
    var canSelectImage: Bool {
        switch self {
        case .idle, .preview, .done:
            return true
        case .selecting, .processing, .printing, .error:
            return false
        }
    }

    /// Whether the user can initiate printing from this state.
    var canPrint: Bool {
        if case .preview = self {
            return true
        }
        return false
    }

    /// Whether the user can reset to idle from this state.
    var canReset: Bool {
        switch self {
        case .done, .error:
            return true
        case .idle, .selecting, .processing, .preview, .printing:
            return false
        }
    }
}

// MARK: - Debug Description

extension AppState: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .idle:
            return "idle"
        case .selecting(let source):
            return "selecting(\(source))"
        case .processing:
            return "processing"
        case .preview:
            return "preview"
        case .printing(let progress):
            return "printing(\(Int(progress * 100))%)"
        case .done:
            return "done"
        case .error(let error):
            return "error(\(error))"
        }
    }
}
