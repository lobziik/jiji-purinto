//
//  ImageNormalizer.swift
//  jiji-purinto
//
//  Normalizes UIImage orientation and converts to CGImage.
//

import UIKit

/// Normalizes images by fixing orientation and converting to CGImage.
///
/// Camera images often have EXIF orientation metadata that needs to be applied
/// to get the correct visual representation. This normalizer renders the image
/// with proper orientation into a new bitmap context.
enum ImageNormalizer {
    /// Normalizes a UIImage by applying its orientation transform.
    ///
    /// This creates a new CGImage with the orientation baked in,
    /// ensuring consistent processing regardless of source.
    ///
    /// - Parameter image: The input UIImage, potentially with orientation metadata.
    /// - Returns: A normalized CGImage with orientation applied.
    /// - Throws: `ProcessingError.invalidImage` if the image cannot be processed.
    static func normalize(_ image: UIImage) throws(ProcessingError) -> CGImage {
        // If the image is already in the correct orientation, extract CGImage directly
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        // Create a bitmap context with the image's point size
        let size = image.size
        guard size.width > 0 && size.height > 0 else {
            throw .invalidImage
        }

        // Use RGB color space for compatibility
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw .invalidImage
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw .invalidImage
        }

        // Draw with high quality
        context.interpolationQuality = .high

        // Draw the image, which automatically applies the orientation transform
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsPushContext(context)
        image.draw(in: rect)
        UIGraphicsPopContext()

        // Extract the resulting CGImage
        guard let normalizedImage = context.makeImage() else {
            throw .invalidImage
        }

        return normalizedImage
    }
}
