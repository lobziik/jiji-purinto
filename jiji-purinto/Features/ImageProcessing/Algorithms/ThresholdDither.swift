//
//  ThresholdDither.swift
//  jiji-purinto
//
//  Simple threshold dithering - fastest but lowest quality.
//

import Foundation

/// Simple threshold dithering algorithm.
///
/// Converts each pixel to black or white based on a threshold value.
/// Fast but produces harsh transitions. Best suited for:
/// - Text and line art
/// - High-contrast images
/// - Performance-critical scenarios
///
/// ## Algorithm
/// ```
/// output = input >= 128 ? white : black
/// ```
struct ThresholdDither: DitherAlgorithmProtocol, Sendable {
    /// The threshold value (0-255). Pixels >= threshold become white.
    let threshold: UInt8

    /// Creates a threshold ditherer with the default threshold (128).
    init() {
        self.threshold = 128
    }

    /// Creates a threshold ditherer with a custom threshold.
    ///
    /// - Parameter threshold: The threshold value (0-255).
    init(threshold: UInt8) {
        self.threshold = threshold
    }

    func dither(pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard pixels.count == width * height else {
            return []
        }

        return pixels.map { pixel in
            pixel >= threshold ? UInt8(0) : UInt8(255)
        }
    }
}
