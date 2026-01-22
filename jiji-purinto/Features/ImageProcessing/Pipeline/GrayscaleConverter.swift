//
//  GrayscaleConverter.swift
//  jiji-purinto
//
//  Converts color images to grayscale using vImage.
//

import Accelerate
import CoreGraphics

/// Converts color images to grayscale using high-performance vImage operations.
///
/// Uses the standard luminance formula (Rec. 709):
/// Y = 0.2126 × R + 0.7152 × G + 0.0722 × B
enum GrayscaleConverter {
    /// Converts a CGImage to grayscale.
    ///
    /// - Parameter image: The input CGImage (can be color or grayscale).
    /// - Returns: A grayscale CGImage.
    /// - Throws: `ProcessingError.conversionFailed` if conversion fails.
    static func convert(_ image: CGImage) throws(ProcessingError) -> CGImage {
        let width = image.width
        let height = image.height

        guard width > 0 && height > 0 else {
            throw .conversionFailed
        }

        // If already grayscale, return as-is
        if image.colorSpace?.model == .monochrome {
            return image
        }

        // Create source buffer from the image
        var sourceBuffer = try createSourceBuffer(from: image)
        defer {
            sourceBuffer.data.deallocate()
        }

        // Create destination buffer for grayscale output
        var destBuffer = vImage_Buffer()
        let destBytesPerRow = width
        let destData = UnsafeMutableRawPointer.allocate(
            byteCount: destBytesPerRow * height,
            alignment: MemoryLayout<UInt8>.alignment
        )
        destBuffer.data = destData
        destBuffer.width = vImagePixelCount(width)
        destBuffer.height = vImagePixelCount(height)
        destBuffer.rowBytes = destBytesPerRow

        defer {
            destData.deallocate()
        }

        // Perform the conversion using vImage
        // The matrix converts ARGB to grayscale using Rec. 709 coefficients
        // Since we're working with ARGB, we need [A, R, G, B] coefficients
        // We want: Y = 0.2126 × R + 0.7152 × G + 0.0722 × B
        let divisor: Int32 = 0x1000  // 4096 for fixed-point math
        let coefficients: [Int16] = [
            0,                          // Alpha (ignored)
            Int16(0.2126 * 4096),       // Red
            Int16(0.7152 * 4096),       // Green
            Int16(0.0722 * 4096)        // Blue
        ]

        let error = vImageMatrixMultiply_ARGB8888ToPlanar8(
            &sourceBuffer,
            &destBuffer,
            coefficients,
            divisor,
            nil,
            0,
            vImage_Flags(kvImageNoFlags)
        )

        guard error == kvImageNoError else {
            throw .conversionFailed
        }

        // Create output CGImage from the grayscale buffer
        guard let grayColorSpace = CGColorSpace(name: CGColorSpace.linearGray) else {
            throw .conversionFailed
        }

        guard let provider = CGDataProvider(
            dataInfo: nil,
            data: destData,
            size: destBytesPerRow * height,
            releaseData: { _, _, _ in }
        ) else {
            throw .conversionFailed
        }

        guard let grayImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: destBytesPerRow,
            space: grayColorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw .conversionFailed
        }

        // Create a copy because the provider references our buffer
        return try copyImage(grayImage)
    }

    /// Extracts grayscale pixel values from a CGImage.
    ///
    /// - Parameter image: A grayscale CGImage.
    /// - Returns: Array of pixel values (0-255), one per pixel.
    /// - Throws: `ProcessingError.conversionFailed` if extraction fails.
    static func extractPixels(from image: CGImage) throws(ProcessingError) -> [UInt8] {
        let width = image.width
        let height = image.height

        guard width > 0 && height > 0 else {
            throw .conversionFailed
        }

        // Create a buffer to hold the pixel data
        var pixels = [UInt8](repeating: 0, count: width * height)

        // Create grayscale context
        guard let grayColorSpace = CGColorSpace(name: CGColorSpace.linearGray) else {
            throw .conversionFailed
        }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: grayColorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw .conversionFailed
        }

        // Draw the image into the context
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixels
    }

    // MARK: - Private Helpers

    /// Creates a vImage buffer from a CGImage, converting to ARGB8888 format.
    ///
    /// Allocates our own buffer and passes it to CGContext to guarantee exact `bytesPerRow`.
    /// This prevents alignment-related artifacts that occur when CGContext chooses its own
    /// `bytesPerRow` (e.g., padding to 16 or 64 byte boundaries).
    private static func createSourceBuffer(from image: CGImage) throws(ProcessingError) -> vImage_Buffer {
        let width = image.width
        let height = image.height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw .conversionFailed
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        let bytesPerRow = width * 4
        let bufferSize = bytesPerRow * height

        // Allocate our own buffer - CGContext MUST use our bytesPerRow when we provide data
        let bufferData = UnsafeMutableRawPointer.allocate(
            byteCount: bufferSize,
            alignment: MemoryLayout<UInt8>.alignment
        )

        guard let context = CGContext(
            data: bufferData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            bufferData.deallocate()
            throw .conversionFailed
        }

        // Draw the image into ARGB format
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // No copy needed - data is already in bufferData
        var buffer = vImage_Buffer()
        buffer.data = bufferData
        buffer.width = vImagePixelCount(width)
        buffer.height = vImagePixelCount(height)
        buffer.rowBytes = bytesPerRow

        return buffer
    }

    /// Creates a copy of a CGImage to ensure independent memory ownership.
    private static func copyImage(_ image: CGImage) throws(ProcessingError) -> CGImage {
        guard let colorSpace = image.colorSpace else {
            throw .conversionFailed
        }

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            throw .conversionFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard let copy = context.makeImage() else {
            throw .conversionFailed
        }

        return copy
    }
}
