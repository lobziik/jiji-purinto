//
//  AtkinsonDither.swift
//  jiji-purinto
//
//  Atkinson dithering - vintage look, uses less ink.
//

import Foundation

/// Atkinson dithering algorithm.
///
/// A variant of error diffusion that produces a distinctive "vintage" look.
/// Only diffuses 6/8 of the error, causing darker areas to become pure black
/// and lighter areas to become pure white. Best suited for:
/// - Vintage/retro aesthetic
/// - Line art with some shading
/// - Reducing ink usage
///
/// ## Error Distribution
/// ```
///        pixel   1/8    1/8
/// 1/8    1/8     1/8
///        1/8
/// ```
///
/// Note: Only 6/8 of error is diffused, 2/8 is discarded.
struct AtkinsonDither: DitherAlgorithmProtocol, Sendable {
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

                // Calculate quantization error (only diffuse 6/8 = 3/4)
                let error = oldPixel - newPixel
                let diffusedError = error / 8

                // Distribute error to 6 neighbors
                // Right: 1/8
                if x + 1 < width {
                    buffer[index + 1] += diffusedError
                }

                // Right+2: 1/8
                if x + 2 < width {
                    buffer[index + 2] += diffusedError
                }

                // Bottom-left: 1/8
                if x > 0 && y + 1 < height {
                    buffer[index + width - 1] += diffusedError
                }

                // Bottom: 1/8
                if y + 1 < height {
                    buffer[index + width] += diffusedError
                }

                // Bottom-right: 1/8
                if x + 1 < width && y + 1 < height {
                    buffer[index + width + 1] += diffusedError
                }

                // Bottom+2: 1/8
                if y + 2 < height {
                    buffer[index + width * 2] += diffusedError
                }
            }
        }

        return result
    }
}
