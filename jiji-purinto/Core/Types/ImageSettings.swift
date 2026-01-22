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
    /// Brightness adjustment. Range: -1.0 to +1.0, default 0.0.
    var brightness: Float

    /// Contrast adjustment. Range: 0.5 to 2.0, default 1.0.
    var contrast: Float

    /// Dithering algorithm for the final 1-bit conversion.
    var algorithm: DitherAlgorithm

    /// Gamma correction value. Range: 0.8 to 2.0, default 1.4.
    /// Values > 1.0 brighten midtones, improving thermal print quality.
    var gamma: Float

    /// Enable automatic levels (histogram stretching).
    /// When true, expands image contrast to use the full dynamic range.
    var autoLevels: Bool

    /// Percentage of pixels to clip from histogram edges. Range: 0.0 to 5.0, default 1.0.
    /// Only applies when autoLevels is enabled.
    var clipPercent: Float

    /// Default settings optimized for thermal printing.
    ///
    /// Uses auto levels and gamma correction to improve print quality.
    static let `default` = ImageSettings(
        brightness: 0.0,
        contrast: 1.0,
        algorithm: .floydSteinberg,
        gamma: 1.4,
        autoLevels: true,
        clipPercent: 1.0
    )
}
