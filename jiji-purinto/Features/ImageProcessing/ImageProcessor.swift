//
//  ImageProcessor.swift
//  jiji-purinto
//
//  Main entry point for image processing pipeline.
//

import UIKit
import CoreGraphics

/// Processes images for thermal printing.
///
/// Orchestrates the full processing pipeline:
/// 1. Normalize orientation
/// 2. Resize to printer width (384px)
/// 3. Convert to grayscale
/// 4. Apply brightness/contrast adjustments
/// 5. Apply dithering algorithm
/// 6. Pack into 1-bit MonoBitmap
///
/// ## Usage
/// ```swift
/// let processor = ImageProcessor()
/// let bitmap = try await processor.process(image: photo, settings: .default)
/// // bitmap is ready for printer
///
/// let preview = try await processor.preview(image: photo, settings: .default, targetSize: CGSize(width: 300, height: 400))
/// // preview is a UIImage for display
/// ```
actor ImageProcessor {
    /// Processes an image for thermal printing.
    ///
    /// Runs the full pipeline: normalize → resize → grayscale → brightness/contrast → dither → pack.
    ///
    /// - Parameters:
    ///   - image: The input UIImage to process.
    ///   - settings: Processing settings (brightness, contrast, algorithm).
    /// - Returns: A 1-bit packed MonoBitmap ready for the printer.
    /// - Throws: `ProcessingError` if any pipeline stage fails.
    func process(image: UIImage, settings: ImageSettings) async throws(ProcessingError) -> MonoBitmap {
        // 1. Normalize orientation
        let normalized = try ImageNormalizer.normalize(image)

        // 2. Resize to printer width
        let resized = try ImageResizer.resize(normalized)

        // 3. Convert to grayscale
        let grayscale = try GrayscaleConverter.convert(resized)

        // 4. Extract pixel values
        var pixels = try GrayscaleConverter.extractPixels(from: grayscale)

        // 5. Apply brightness/contrast
        pixels = BrightnessContrast.apply(
            to: pixels,
            brightness: settings.brightness,
            contrast: settings.contrast
        )

        // 6. Apply dithering
        let ditherer = DitherAlgorithmFactory.create(for: settings.algorithm)
        let ditheredPixels = ditherer.dither(
            pixels: pixels,
            width: resized.width,
            height: resized.height
        )

        guard ditheredPixels.count == resized.width * resized.height else {
            throw .ditherFailed
        }

        // 7. Pack into MonoBitmap
        do {
            return try MonoBitmap(
                width: resized.width,
                height: resized.height,
                pixels: ditheredPixels
            )
        } catch {
            throw .ditherFailed
        }
    }

    /// Generates a preview image with the current settings applied.
    ///
    /// The preview shows what the printed image will look like, scaled to fit
    /// the target size for display purposes.
    ///
    /// - Parameters:
    ///   - image: The input UIImage to preview.
    ///   - settings: Processing settings (brightness, contrast, algorithm).
    ///   - targetSize: Maximum size for the preview image.
    /// - Returns: A UIImage preview showing the dithered result.
    /// - Throws: `ProcessingError` if processing fails.
    func preview(
        image: UIImage,
        settings: ImageSettings,
        targetSize: CGSize
    ) async throws(ProcessingError) -> UIImage {
        // Process the full image first
        let bitmap = try await process(image: image, settings: settings)

        // Convert MonoBitmap to UIImage for display
        let previewImage = try bitmapToUIImage(bitmap)

        // Resize to target size if needed
        return resizeForPreview(previewImage, targetSize: targetSize)
    }

    /// Generates a quick preview by processing at reduced resolution.
    ///
    /// Faster than full preview, suitable for live settings adjustments.
    ///
    /// - Parameters:
    ///   - image: The input UIImage to preview.
    ///   - settings: Processing settings (brightness, contrast, algorithm).
    ///   - previewWidth: Width to process at (smaller = faster).
    /// - Returns: A UIImage preview.
    /// - Throws: `ProcessingError` if processing fails.
    func quickPreview(
        image: UIImage,
        settings: ImageSettings,
        previewWidth: Int = 192
    ) async throws(ProcessingError) -> UIImage {
        // 1. Normalize orientation
        let normalized = try ImageNormalizer.normalize(image)

        // 2. Resize to preview width (smaller than full resolution)
        let resized = try ImageResizer.resize(normalized, toWidth: previewWidth)

        // 3. Convert to grayscale
        let grayscale = try GrayscaleConverter.convert(resized)

        // 4. Extract pixel values
        var pixels = try GrayscaleConverter.extractPixels(from: grayscale)

        // 5. Apply brightness/contrast
        pixels = BrightnessContrast.apply(
            to: pixels,
            brightness: settings.brightness,
            contrast: settings.contrast
        )

        // 6. Apply dithering
        let ditherer = DitherAlgorithmFactory.create(for: settings.algorithm)
        let ditheredPixels = ditherer.dither(
            pixels: pixels,
            width: resized.width,
            height: resized.height
        )

        guard ditheredPixels.count == resized.width * resized.height else {
            throw .ditherFailed
        }

        // 7. Convert to UIImage for display
        return try pixelsToUIImage(
            ditheredPixels,
            width: resized.width,
            height: resized.height
        )
    }

    // MARK: - Private Helpers

    /// Converts a MonoBitmap to UIImage for display.
    private func bitmapToUIImage(_ bitmap: MonoBitmap) throws(ProcessingError) -> UIImage {
        // Unpack bits to bytes for display
        var pixels = [UInt8](repeating: 0, count: bitmap.width * bitmap.height)

        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                let index = y * bitmap.width + x
                // In MonoBitmap: 1 = black, 0 = white
                // For display: 0 = black, 255 = white
                pixels[index] = bitmap.pixel(at: x, y: y) ? 0 : 255
            }
        }

        return try pixelsToUIImage(pixels, width: bitmap.width, height: bitmap.height)
    }

    /// Converts grayscale pixel array to UIImage.
    private func pixelsToUIImage(
        _ pixels: [UInt8],
        width: Int,
        height: Int
    ) throws(ProcessingError) -> UIImage {
        guard !pixels.isEmpty, width > 0, height > 0 else {
            throw .conversionFailed
        }

        guard let grayColorSpace = CGColorSpace(name: CGColorSpace.linearGray) else {
            throw .conversionFailed
        }

        var mutablePixels = pixels
        let image: CGImage? = mutablePixels.withUnsafeMutableBytes { buffer in
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

        guard let cgImage = image else {
            throw .conversionFailed
        }

        return UIImage(cgImage: cgImage)
    }

    /// Resizes a UIImage to fit within target size.
    private func resizeForPreview(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        // If already fits, return as-is
        if size.width <= targetSize.width && size.height <= targetSize.height {
            return image
        }

        // Calculate scale to fit
        let widthScale = targetSize.width / size.width
        let heightScale = targetSize.height / size.height
        let scale = min(widthScale, heightScale)

        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
