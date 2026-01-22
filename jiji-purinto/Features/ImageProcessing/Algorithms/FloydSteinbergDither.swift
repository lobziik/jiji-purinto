//
//  FloydSteinbergDither.swift
//  jiji-purinto
//
//  Floyd-Steinberg error diffusion dithering - best for photos.
//

import Foundation

/// Floyd-Steinberg error diffusion dithering algorithm with gamma-aware processing.
///
/// Performs dithering in linear color space for perceptually correct results.
/// sRGB values are converted to linear space before error diffusion, which
/// ensures that mid-tones are preserved correctly (sRGB 128 ≈ 22% linear brightness,
/// not 50% as naive dithering assumes).
///
/// Reference: https://www.nayuki.io/page/gamma-aware-image-dithering
///
/// ## Error Distribution
/// ```
///        pixel   7/16
/// 3/16   5/16    1/16
/// ```
///
/// The algorithm processes pixels left-to-right, top-to-bottom.
/// Quantization error is distributed to unprocessed neighbors in linear space.
struct FloydSteinbergDither: DitherAlgorithmProtocol, Sendable {
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

    func dither(pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard pixels.count == width * height, width > 0, height > 0 else {
            return []
        }

        // Convert to LINEAR space for correct error diffusion
        var buffer = pixels.map { Self.srgbToLinearTable[Int($0)] }
        var result = [UInt8](repeating: 0, count: pixels.count)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = buffer[index]  // In linear space

                // Quantize with threshold 0.5 in LINEAR space (not 128 in sRGB!)
                // This ensures perceptually correct mid-tone reproduction.
                let newPixel: Float = oldPixel >= 0.5 ? 1.0 : 0.0

                // Output: 255 = black, 0 = white (for MonoBitmap)
                result[index] = newPixel == 0 ? 255 : 0

                // Error in linear space
                let error = oldPixel - newPixel

                // Distribute error to neighbors (in linear space!)
                // Right: 7/16
                if x + 1 < width {
                    buffer[index + 1] += error * 7 / 16
                }

                // Bottom-left: 3/16
                if x > 0 && y + 1 < height {
                    buffer[index + width - 1] += error * 3 / 16
                }

                // Bottom: 5/16
                if y + 1 < height {
                    buffer[index + width] += error * 5 / 16
                }

                // Bottom-right: 1/16
                if x + 1 < width && y + 1 < height {
                    buffer[index + width + 1] += error * 1 / 16
                }
            }
        }

        return result
    }
}
