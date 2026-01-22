//
//  ThresholdDither.swift
//  jiji-purinto
//
//  Simple threshold dithering - fastest but lowest quality.
//

import Foundation

/// Simple threshold dithering algorithm with gamma-aware processing.
///
/// Converts each pixel to black or white based on a threshold in linear color space.
/// By default, uses 0.5 linear (equivalent to ~186 sRGB) which represents true
/// perceptual middle gray. This ensures dark tones stay dark and light tones stay light.
///
/// Reference: https://www.nayuki.io/page/gamma-aware-image-dithering
///
/// ## Algorithm
/// Pixel is converted to linear space, then compared to threshold:
/// ```
/// linearValue = srgbToLinear(input)
/// output = linearValue >= threshold ? white : black
/// ```
struct ThresholdDither: DitherAlgorithmProtocol, Sendable {
    /// Precomputed sRGB → Linear lookup table for performance.
    ///
    /// Converts sRGB gamma-encoded values (0-255) to linear light values (0.0-1.0).
    /// Uses the standard sRGB transfer function.
    private static let srgbToLinearTable: [Float] = {
        (0..<256).map { i in
            let x = Float(i) / 255.0
            if x <= 0.04045 {
                return x / 12.92
            } else {
                return powf((x + 0.055) / 1.055, 2.4)
            }
        }
    }()

    /// The threshold value in linear space (0.0-1.0).
    ///
    /// Default is 0.5, which represents perceptual middle gray.
    /// In sRGB space, this corresponds to approximately value 186.
    let linearThreshold: Float

    /// Creates a threshold ditherer with the default threshold (0.5 linear, perceptual middle gray).
    init() {
        self.linearThreshold = 0.5
    }

    /// Creates a threshold ditherer with a custom sRGB threshold.
    ///
    /// The sRGB value is converted to linear space internally.
    ///
    /// - Parameter threshold: The threshold value in sRGB space (0-255).
    init(threshold: UInt8) {
        self.linearThreshold = Self.srgbToLinearTable[Int(threshold)]
    }

    /// Creates a threshold ditherer with a custom linear threshold.
    ///
    /// - Parameter linearThreshold: The threshold value in linear space (0.0-1.0).
    init(linearThreshold: Float) {
        self.linearThreshold = linearThreshold
    }

    func dither(pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard pixels.count == width * height else {
            return []
        }

        return pixels.map { pixel in
            // Convert to linear space for perceptually correct thresholding
            let linear = Self.srgbToLinearTable[Int(pixel)]
            return linear >= linearThreshold ? UInt8(0) : UInt8(255)
        }
    }
}
