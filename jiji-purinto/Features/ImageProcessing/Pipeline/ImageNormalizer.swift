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

        // Use UIGraphicsImageRenderer which properly handles orientation.
        // Unlike raw CGContext, UIGraphicsImageRenderer applies the correct
        // affine transforms based on UIImage.imageOrientation internally.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // Use actual pixel dimensions, not scaled
        format.preferredRange = .standard  // Force 8-bit sRGB, not extended color (16-bit float)

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalizedUIImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        guard let normalizedImage = normalizedUIImage.cgImage else {
            throw .invalidImage
        }

        return normalizedImage
    }
}
