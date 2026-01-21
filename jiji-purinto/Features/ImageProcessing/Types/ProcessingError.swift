//
//  ProcessingError.swift
//  jiji-purinto
//
//  Error types for image processing pipeline.
//

import Foundation

/// Errors that can occur during image processing.
///
/// Each error case provides specific information about what went wrong
/// during the processing pipeline, enabling proper error handling and
/// user feedback.
enum ProcessingError: Error, Equatable, Sendable {
    /// The input image is invalid or could not be read.
    ///
    /// This occurs when the image data is corrupted, in an unsupported format,
    /// or when CGImage conversion fails.
    case invalidImage

    /// The image could not be resized to the target width.
    ///
    /// This occurs when Core Graphics fails to create the resized bitmap context
    /// or draw the scaled image.
    case resizeFailed

    /// The image could not be converted to grayscale.
    ///
    /// This occurs when vImage operations fail during color-to-grayscale conversion.
    case conversionFailed

    /// The dithering algorithm failed to process the image.
    ///
    /// This occurs when the dithering operation encounters an error,
    /// such as invalid pixel data or memory allocation failure.
    case ditherFailed

    /// An unexpected error occurred during processing.
    ///
    /// Contains the underlying error description for debugging purposes.
    case unexpected(String)
}

// MARK: - LocalizedError

extension ProcessingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image could not be read or is in an unsupported format."
        case .resizeFailed:
            return "Failed to resize the image to print width."
        case .conversionFailed:
            return "Failed to convert the image to grayscale."
        case .ditherFailed:
            return "Failed to apply dithering algorithm."
        case .unexpected(let message):
            return "Unexpected error: \(message)"
        }
    }
}
