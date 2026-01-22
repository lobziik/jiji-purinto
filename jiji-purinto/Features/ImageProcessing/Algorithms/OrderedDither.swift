//
//  OrderedDither.swift
//  jiji-purinto
//
//  Ordered (Bayer) dithering - produces regular patterns.
//

import Foundation

/// Ordered dithering using an 8×8 Bayer matrix with gamma-aware processing.
///
/// For gamma-aware ordered dithering, we convert the input pixel to linear space
/// and compare against uniformly-distributed linear thresholds. This ensures
/// that sRGB 128 (~22% linear) produces ~22% white dots, not ~50%.
///
/// Reference: https://www.nayuki.io/page/gamma-aware-image-dithering
///
/// ## 8×8 Bayer Matrix
/// The threshold matrix creates the dithering pattern. Each pixel's threshold
/// is determined by its position modulo 8 in the matrix.
struct OrderedDither: DitherAlgorithmProtocol, Sendable {
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

    /// 8×8 Bayer matrix with thresholds uniformly distributed in LINEAR space.
    ///
    /// For gamma-aware ordered dithering, thresholds must be uniformly distributed
    /// in linear light space (0.0-1.0), not in sRGB space. This ensures correct
    /// tone reproduction when comparing against linear pixel values.
    ///
    /// The threshold values are: index/64 for the standard Bayer pattern positions.
    private static let bayerMatrixLinear: [Float] = {
        // Standard 8×8 Bayer pattern indices (0-63)
        let bayerIndices: [Int] = [
             0, 32,  8, 40,  2, 34, 10, 42,
            48, 16, 56, 24, 50, 18, 58, 26,
            12, 44,  4, 36, 14, 46,  6, 38,
            60, 28, 52, 20, 62, 30, 54, 22,
             3, 35, 11, 43,  1, 33,  9, 41,
            51, 19, 59, 27, 49, 17, 57, 25,
            15, 47,  7, 39, 13, 45,  5, 37,
            63, 31, 55, 23, 61, 29, 53, 21
        ]
        // Convert to uniform linear thresholds (0/64, 1/64, ..., 63/64)
        return bayerIndices.map { Float($0) / 64.0 }
    }()

    func dither(pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard pixels.count == width * height, width > 0, height > 0 else {
            return []
        }

        var result = [UInt8](repeating: 0, count: pixels.count)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixel = pixels[index]

                // Convert pixel to linear space
                let linearPixel = Self.srgbToLinearTable[Int(pixel)]

                // Get threshold from Bayer matrix (uniformly distributed in linear space)
                let matrixX = x % 8
                let matrixY = y % 8
                let linearThreshold = Self.bayerMatrixLinear[matrixY * 8 + matrixX]

                // Compare in linear space
                // Pixel >= threshold means white (0), otherwise black (255)
                result[index] = linearPixel >= linearThreshold ? 0 : 255
            }
        }

        return result
    }
}
