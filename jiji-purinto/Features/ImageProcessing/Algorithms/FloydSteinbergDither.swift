//
//  FloydSteinbergDither.swift
//  jiji-purinto
//
//  Floyd-Steinberg error diffusion dithering - best for photos.
//

import Foundation

/// Floyd-Steinberg error diffusion dithering algorithm.
///
/// Diffuses quantization error to neighboring pixels, creating smooth
/// gradients that approximate continuous tones. Best suited for:
/// - Photographs
/// - Images with smooth gradients
/// - High-quality output
///
/// ## Error Distribution
/// ```
///        pixel   7/16
/// 3/16   5/16    1/16
/// ```
///
/// The algorithm processes pixels left-to-right, top-to-bottom.
/// Quantization error is distributed to unprocessed neighbors.
struct FloydSteinbergDither: DitherAlgorithmProtocol, Sendable {
    func dither(pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard pixels.count == width * height, width > 0, height > 0 else {
            return []
        }

        // Work with Float for error accumulation
        var buffer = pixels.map { Float($0) }
        var result = [UInt8](repeating: 0, count: pixels.count)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = buffer[index]

                // Quantize to black or white
                let newPixel: Float = oldPixel >= 128 ? 255 : 0
                result[index] = newPixel == 0 ? 255 : 0  // Invert: 0=white in output, 255=black

                // Calculate quantization error
                let error = oldPixel - newPixel

                // Distribute error to neighbors (if they exist)
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
