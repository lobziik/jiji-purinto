//
//  OrderedDither.swift
//  jiji-purinto
//
//  Ordered (Bayer) dithering - produces regular patterns.
//

import Foundation

/// Ordered dithering using an 8×8 Bayer matrix.
///
/// Produces a characteristic crosshatch pattern instead of random-looking noise.
/// The regularity can be aesthetically pleasing for certain images.
/// Best suited for:
/// - Stylized/artistic effects
/// - Images where pattern regularity is desired
/// - Animation (no temporal noise between frames)
///
/// ## 8×8 Bayer Matrix
/// The threshold matrix creates the dithering pattern. Each pixel's threshold
/// is determined by its position modulo 8 in the matrix.
struct OrderedDither: DitherAlgorithmProtocol, Sendable {
    /// 8×8 Bayer matrix normalized to 0-255 range.
    ///
    /// The original Bayer matrix values (0-63) are scaled to fit the full
    /// grayscale range for direct comparison with pixel values.
    private static let bayerMatrix: [UInt8] = [
          0, 128,  32, 160,   8, 136,  40, 168,
        192,  64, 224,  96, 200,  72, 232, 104,
         48, 176,  16, 144,  56, 184,  24, 152,
        240, 112, 208,  80, 248, 120, 216,  88,
         12, 140,  44, 172,   4, 132,  36, 164,
        204,  76, 236, 108, 196,  68, 228, 100,
         60, 188,  28, 156,  52, 180,  20, 148,
        252, 124, 220,  92, 244, 116, 212,  84
    ]

    func dither(pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard pixels.count == width * height, width > 0, height > 0 else {
            return []
        }

        var result = [UInt8](repeating: 0, count: pixels.count)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixel = pixels[index]

                // Get threshold from Bayer matrix based on position
                let matrixX = x % 8
                let matrixY = y % 8
                let threshold = Self.bayerMatrix[matrixY * 8 + matrixX]

                // Compare pixel to threshold
                // Pixel >= threshold means white (0), otherwise black (255)
                result[index] = pixel >= threshold ? 0 : 255
            }
        }

        return result
    }
}
