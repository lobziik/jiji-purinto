//
//  BrightnessContrast.swift
//  jiji-purinto
//
//  Applies brightness and contrast adjustments to grayscale images.
//

import Accelerate
import CoreGraphics

/// Applies brightness and contrast adjustments to grayscale images.
///
/// Uses vImage for high-performance pixel manipulation.
///
/// ## Formulas
/// The adjustment is applied using: `output = (input - 128) × contrast + 128 + brightness × 255`
///
/// This centers the contrast adjustment around mid-gray (128) and applies
/// brightness as an offset.
enum BrightnessContrast {
    /// Applies brightness and contrast adjustments to grayscale pixel data.
    ///
    /// - Parameters:
    ///   - pixels: Array of grayscale pixel values (0-255).
    ///   - brightness: Brightness adjustment (-1.0 to +1.0). Default 0.
    ///   - contrast: Contrast multiplier (0.5 to 2.0). Default 1.0.
    /// - Returns: Adjusted pixel array.
    static func apply(
        to pixels: [UInt8],
        brightness: Float,
        contrast: Float
    ) -> [UInt8] {
        guard !pixels.isEmpty else { return [] }

        // Clamp parameters to valid ranges
        let clampedBrightness = max(-1.0, min(1.0, brightness))
        let clampedContrast = max(0.5, min(2.0, contrast))

        // Early exit if no adjustment needed
        if clampedBrightness == 0 && clampedContrast == 1.0 {
            return pixels
        }

        // Convert brightness to 0-255 scale offset
        let brightnessOffset = clampedBrightness * 255.0

        var result = [UInt8](repeating: 0, count: pixels.count)

        // Build lookup table for fast processing
        var lookupTable = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 {
            // Apply contrast centered at 128, then brightness offset
            let value = Float(i)
            let adjusted = (value - 128.0) * clampedContrast + 128.0 + brightnessOffset
            // Clamp to 0-255
            lookupTable[i] = UInt8(max(0, min(255, adjusted)))
        }

        // Apply lookup table using vImage for best performance
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

    /// Applies brightness and contrast adjustments to a grayscale CGImage.
    ///
    /// - Parameters:
    ///   - image: Input grayscale CGImage.
    ///   - brightness: Brightness adjustment (-1.0 to +1.0). Default 0.
    ///   - contrast: Contrast multiplier (0.5 to 2.0). Default 1.0.
    /// - Returns: Adjusted CGImage.
    /// - Throws: `ProcessingError.conversionFailed` if processing fails.
    static func apply(
        to image: CGImage,
        brightness: Float,
        contrast: Float
    ) throws(ProcessingError) -> CGImage {
        let width = image.width
        let height = image.height

        // Extract pixels
        var pixels = try GrayscaleConverter.extractPixels(from: image)

        // Apply adjustments
        pixels = apply(to: pixels, brightness: brightness, contrast: contrast)

        // Create output image
        guard let grayColorSpace = CGColorSpace(name: CGColorSpace.linearGray) else {
            throw .conversionFailed
        }

        let result: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: grayColorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return nil
            }

            return context.makeImage()
        }

        guard let outputImage = result else {
            throw .conversionFailed
        }

        return outputImage
    }
}
