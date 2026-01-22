//
//  HistogramStretch.swift
//  jiji-purinto
//
//  Applies histogram stretching (auto levels) to grayscale images.
//

import Accelerate

/// Applies histogram stretching to expand image contrast to full dynamic range.
///
/// Finds the actual min/max pixel values (with optional clipping) and stretches
/// them to fill the full 0-255 range. This improves contrast in images that
/// don't use the full tonal range.
///
/// ## Algorithm
/// 1. Build histogram of all pixel values
/// 2. Find black point (value below which clipPercent% of pixels fall)
/// 3. Find white point (value above which clipPercent% of pixels fall)
/// 4. Remap all values: `output = (input - blackPoint) * 255 / (whitePoint - blackPoint)`
enum HistogramStretch {
    /// Stretches image histogram to full 0-255 range.
    ///
    /// - Parameters:
    ///   - pixels: Grayscale pixel array with values 0-255.
    ///   - clipPercent: Percentage of pixels to clip from each edge (0.0-5.0). Default 1.0.
    /// - Returns: Histogram-stretched pixel array.
    static func apply(to pixels: [UInt8], clipPercent: Float = 1.0) -> [UInt8] {
        guard !pixels.isEmpty else { return [] }

        // Clamp clipPercent to valid range
        let clampedClipPercent = max(0.0, min(5.0, clipPercent))

        // Build histogram
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in pixels {
            histogram[Int(pixel)] += 1
        }

        let totalPixels = pixels.count
        let clipCount = Int(Float(totalPixels) * clampedClipPercent / 100.0)

        // Find black point (value below which clipCount pixels fall)
        var blackPoint = 0
        var cumulativeCount = 0
        for i in 0..<256 {
            cumulativeCount += histogram[i]
            if cumulativeCount > clipCount {
                blackPoint = i
                break
            }
        }

        // Find white point (value above which clipCount pixels fall)
        var whitePoint = 255
        cumulativeCount = 0
        for i in stride(from: 255, through: 0, by: -1) {
            cumulativeCount += histogram[i]
            if cumulativeCount > clipCount {
                whitePoint = i
                break
            }
        }

        // Handle edge cases: all pixels equal or invalid range
        if blackPoint >= whitePoint {
            return pixels
        }

        // Build lookup table for the stretch transformation
        var lookupTable = [UInt8](repeating: 0, count: 256)
        let range = Float(whitePoint - blackPoint)

        for i in 0..<256 {
            if i <= blackPoint {
                lookupTable[i] = 0
            } else if i >= whitePoint {
                lookupTable[i] = 255
            } else {
                let stretched = Float(i - blackPoint) * 255.0 / range
                lookupTable[i] = UInt8(max(0, min(255, stretched)))
            }
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
