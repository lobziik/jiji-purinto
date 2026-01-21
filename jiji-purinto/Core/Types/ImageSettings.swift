//
//  ImageSettings.swift
//  jiji-purinto
//
//  Image processing settings for thermal printing.
//

import Foundation

/// Dithering algorithm for converting grayscale to 1-bit.
enum DitherAlgorithm: String, CaseIterable, Sendable {
    /// Simple threshold - fast but low quality. Best for text and line art.
    case threshold

    /// Floyd-Steinberg error diffusion - best for photos.
    case floydSteinberg

    /// Atkinson dithering - vintage look, uses less ink.
    case atkinson

    /// Ordered dithering - produces regular patterns.
    case ordered
}

/// Settings for image processing before printing.
///
/// These settings control how the image is converted to a 1-bit bitmap
/// suitable for thermal printing.
struct ImageSettings: Equatable, Sendable {
    /// Brightness adjustment. Range: -1.0 to +1.0, default 0.
    var brightness: Float

    /// Contrast adjustment. Range: 0.5 to 2.0, default 1.0.
    var contrast: Float

    /// Dithering algorithm for the final 1-bit conversion.
    var algorithm: DitherAlgorithm

    /// Default settings optimized for thermal printing.
    ///
    /// Slightly brighter and more contrasty to compensate for thermal printer characteristics.
    static let `default` = ImageSettings(
        brightness: 0.05,
        contrast: 1.1,
        algorithm: .floydSteinberg
    )
}
