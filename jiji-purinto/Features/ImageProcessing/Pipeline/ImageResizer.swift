//
//  ImageResizer.swift
//  jiji-purinto
//
//  Resizes images to the thermal printer width.
//

import CoreGraphics

/// Resizes images to fit the thermal printer's fixed width.
///
/// Uses high-quality Lanczos resampling via Core Graphics for best results
/// with photographic content.
enum ImageResizer {
    /// Resizes a CGImage to the thermal printer width (384 pixels).
    ///
    /// The image is scaled proportionally to fit the printer width,
    /// maintaining aspect ratio. The height is calculated automatically.
    ///
    /// - Parameter image: The input CGImage to resize.
    /// - Returns: A resized CGImage with width = 384 pixels.
    /// - Throws: `ProcessingError.resizeFailed` if resizing fails.
    static func resize(_ image: CGImage) throws(ProcessingError) -> CGImage {
        try resize(image, toWidth: PrinterConstants.printWidth)
    }

    /// Resizes a CGImage to a specific width, maintaining aspect ratio.
    ///
    /// - Parameters:
    ///   - image: The input CGImage to resize.
    ///   - targetWidth: The desired output width in pixels.
    /// - Returns: A resized CGImage with the specified width.
    /// - Throws: `ProcessingError.resizeFailed` if resizing fails.
    static func resize(_ image: CGImage, toWidth targetWidth: Int) throws(ProcessingError) -> CGImage {
        let originalWidth = image.width
        let originalHeight = image.height

        guard originalWidth > 0 && originalHeight > 0 else {
            throw .resizeFailed
        }

        // Calculate proportional height
        let scale = Double(targetWidth) / Double(originalWidth)
        let targetHeight = Int(Double(originalHeight) * scale)

        guard targetHeight > 0 else {
            throw .resizeFailed
        }

        // Create bitmap context for the resized image
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else {
            throw .resizeFailed
        }

        // Use the same bitmap info as the source, or a sensible default
        let bitmapInfo = image.bitmapInfo.rawValue != 0
            ? image.bitmapInfo.rawValue
            : CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw .resizeFailed
        }

        // Use high-quality interpolation (Lanczos)
        context.interpolationQuality = .high

        // Draw the scaled image
        let targetRect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        context.draw(image, in: targetRect)

        // Extract the resized image
        guard let resizedImage = context.makeImage() else {
            throw .resizeFailed
        }

        return resizedImage
    }

    /// Resizes a CGImage to fit within a maximum dimension while maintaining aspect ratio.
    ///
    /// This is useful for generating preview images that fit within a given size.
    ///
    /// - Parameters:
    ///   - image: The input CGImage to resize.
    ///   - maxDimension: The maximum width or height in pixels.
    /// - Returns: A resized CGImage that fits within the specified bounds.
    /// - Throws: `ProcessingError.resizeFailed` if resizing fails.
    static func resizeToFit(_ image: CGImage, maxDimension: Int) throws(ProcessingError) -> CGImage {
        let originalWidth = image.width
        let originalHeight = image.height

        guard originalWidth > 0 && originalHeight > 0 else {
            throw .resizeFailed
        }

        // If already smaller than max, return as-is
        if originalWidth <= maxDimension && originalHeight <= maxDimension {
            return image
        }

        // Calculate scale to fit within bounds
        let widthScale = Double(maxDimension) / Double(originalWidth)
        let heightScale = Double(maxDimension) / Double(originalHeight)
        let scale = min(widthScale, heightScale)

        let targetWidth = Int(Double(originalWidth) * scale)
        let targetHeight = Int(Double(originalHeight) * scale)

        guard targetWidth > 0 && targetHeight > 0 else {
            throw .resizeFailed
        }

        // Create bitmap context
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else {
            throw .resizeFailed
        }

        let bitmapInfo = image.bitmapInfo.rawValue != 0
            ? image.bitmapInfo.rawValue
            : CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw .resizeFailed
        }

        context.interpolationQuality = .high

        let targetRect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        context.draw(image, in: targetRect)

        guard let resizedImage = context.makeImage() else {
            throw .resizeFailed
        }

        return resizedImage
    }
}
