//
//  AppEvent.swift
//  jiji-purinto
//
//  Events that trigger state transitions in the app FSM.
//

import UIKit

/// Events that can trigger state transitions in the application FSM.
///
/// - Note: This enum is marked `@unchecked Sendable` because UIImage is not Sendable.
///   For v0.2, consider migrating to image ID + repository pattern for proper concurrency safety.
enum AppEvent: @unchecked Sendable {
    // MARK: - Image Selection

    /// User wants to select a photo from the gallery.
    case openGallery

    /// User cancelled the image selection.
    case cancelSelection

    /// User selected an image.
    case imageSelected(UIImage)

    /// Image selection failed.
    case imageSelectionFailed(AppError)

    // MARK: - Processing

    /// Image processing completed successfully.
    case processingComplete(UIImage)

    /// Image processing failed.
    case processingFailed(AppError)

    // MARK: - Preview & Settings

    /// User changed the image processing settings.
    case settingsChanged(ImageSettings)

    // MARK: - Printing

    /// User wants to print the image.
    case print

    /// Print progress updated.
    case printProgress(Float)

    /// Print completed successfully.
    case printSuccess

    /// Print failed.
    case printFailed(AppError)

    // MARK: - Recovery

    /// Reset the app to idle state.
    case reset
}

// MARK: - Debug Description

extension AppEvent: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .openGallery:
            return "openGallery"
        case .cancelSelection:
            return "cancelSelection"
        case .imageSelected:
            return "imageSelected"
        case .imageSelectionFailed(let error):
            return "imageSelectionFailed(\(error))"
        case .processingComplete:
            return "processingComplete"
        case .processingFailed(let error):
            return "processingFailed(\(error))"
        case .settingsChanged:
            return "settingsChanged"
        case .print:
            return "print"
        case .printProgress(let progress):
            return "printProgress(\(Int(progress * 100))%)"
        case .printSuccess:
            return "printSuccess"
        case .printFailed(let error):
            return "printFailed(\(error))"
        case .reset:
            return "reset"
        }
    }
}
