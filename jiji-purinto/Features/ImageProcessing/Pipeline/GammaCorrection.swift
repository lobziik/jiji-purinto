//
//  GammaCorrection.swift
//  jiji-purinto
//
//  Applies gamma correction to grayscale images.
//

import Accelerate

/// Applies gamma correction to adjust midtone brightness.
///
/// Gamma correction applies a power function to pixel values, which
/// primarily affects midtones while preserving black (0) and white (255).
///
/// ## Formula
/// `output = 255 × (input / 255) ^ (1 / gamma)`
///
/// - Gamma > 1.0: Brightens midtones (good for thermal printing)
/// - Gamma < 1.0: Darkens midtones
/// - Gamma = 1.0: No change (linear)
enum GammaCorrection {
    /// Applies gamma correction to grayscale pixel data.
    ///
    /// - Parameters:
    ///   - pixels: Grayscale pixel array with values 0-255.
    ///   - gamma: Gamma value (0.8-2.0). Default 1.4. Values > 1.0 brighten midtones.
    /// - Returns: Gamma-corrected pixel array.
    static func apply(to pixels: [UInt8], gamma: Float = 1.4) -> [UInt8] {
        guard !pixels.isEmpty else { return [] }

        // Clamp gamma to valid range
        let clampedGamma = max(0.8, min(2.0, gamma))

        // Early exit if no correction needed
        if clampedGamma == 1.0 {
            return pixels
        }

        // Build lookup table for the gamma transformation
        // Formula: output = 255 * (input/255)^(1/gamma)
        var lookupTable = [UInt8](repeating: 0, count: 256)
        let inverseGamma = 1.0 / clampedGamma

        for i in 0..<256 {
            let normalized = Float(i) / 255.0
            let corrected = powf(normalized, inverseGamma)
            let output = corrected * 255.0
            lookupTable[i] = UInt8(max(0, min(255, output.rounded())))
        }

        // Apply lookup table using vImage for best performance
        var result = [UInt8](repeating: 0, count: pixels.count)

        pixels.withUnsafeBufferPointer { srcPtr in
            result.withUnsafeMutableBufferPointer { dstPtr in
                lookupTable.withUnsafeBufferPointer { tablePtr in
                    var srcBuffer = vImage_Buffer(
                        data: UnsafeMutableRawPointer(mutating: srcPtr.baseAddress!),
                        height: 1,
                        width: vImagePixelCount(pixels.count),
                        rowBytes: pixels.count
                    )
                    var dstBuffer = vImage_Buffer(
                        data: dstPtr.baseAddress!,
                        height: 1,
                        width: vImagePixelCount(pixels.count),
                        rowBytes: pixels.count
                    )

                    vImageTableLookUp_Planar8(
                        &srcBuffer,
                        &dstBuffer,
                        tablePtr.baseAddress!,
                        vImage_Flags(kvImageNoFlags)
                    )
                }
            }
        }

        return result
    }
}
