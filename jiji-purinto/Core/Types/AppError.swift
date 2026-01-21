//
//  AppError.swift
//  jiji-purinto
//
//  Application-level errors.
//

import Foundation

/// Application-level errors that can occur during user operations.
enum AppError: Error, Equatable {
    /// Operation was cancelled by the user.
    case cancelled

    /// Image processing failed.
    case processingFailed(reason: String)

    /// Printing failed.
    case printingFailed(reason: String)

    /// Printer is not connected.
    case printerNotReady

    /// An unexpected error occurred.
    case unexpected(String)
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operation cancelled"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .printingFailed(let reason):
            return "Printing failed: \(reason)"
        case .printerNotReady:
            return "Printer is not connected"
        case .unexpected(let message):
            return "Unexpected error: \(message)"
        }
    }
}
