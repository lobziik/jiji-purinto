//
//  MonoBitmap.swift
//  jiji-purinto
//
//  1-bit packed bitmap for thermal printer output.
//

import Foundation

/// Constants for thermal printer output.
enum PrinterConstants {
    /// Width in pixels for the Cat/MX thermal printer.
    static let printWidth = 384

    /// Bytes per row (384 pixels / 8 bits per byte).
    static let bytesPerRow = 48
}

/// A 1-bit packed bitmap suitable for thermal printer output.
///
/// The bitmap stores pixels as packed bits, where each byte contains 8 pixels.
/// Bit 0 (LSB) represents the leftmost pixel in each byte (LSB first order).
/// A bit value of 1 represents black, 0 represents white.
///
/// ## Memory Layout
/// - Pixels are stored left-to-right, top-to-bottom
/// - Each row is exactly `bytesPerRow` (48) bytes = 384 pixels
/// - Total data size = height × bytesPerRow bytes
///
/// ## Example
/// ```swift
/// let bitmap = MonoBitmap(width: 384, height: 100, data: packedData)
/// let firstRowBytes = bitmap.row(at: 0) // Returns 48 bytes for row 0
/// ```
struct MonoBitmap: Equatable, Sendable {
    /// Width of the bitmap in pixels. Always 384 for thermal printer.
    let width: Int

    /// Height of the bitmap in pixels.
    let height: Int

    /// Packed 1-bit pixel data.
    ///
    /// Each byte contains 8 pixels, LSB first (bit 0 = leftmost pixel).
    /// Data size must equal `height × bytesPerRow`.
    let data: Data

    /// Bytes per row (always 48 for 384px width).
    var bytesPerRow: Int {
        PrinterConstants.bytesPerRow
    }

    /// Total number of pixels in the bitmap.
    var pixelCount: Int {
        width * height
    }

    /// Creates a MonoBitmap with the specified dimensions and packed data.
    ///
    /// - Parameters:
    ///   - width: Width in pixels. Must be exactly 384.
    ///   - height: Height in pixels. Must be positive.
    ///   - data: Packed 1-bit pixel data. Size must equal `height × 48`.
    /// - Throws: `MonoBitmapError` if parameters are invalid.
    init(width: Int, height: Int, data: Data) throws(MonoBitmapError) {
        guard width == PrinterConstants.printWidth else {
            throw .invalidWidth(width)
        }
        guard height > 0 else {
            throw .invalidHeight(height)
        }
        let expectedSize = height * PrinterConstants.bytesPerRow
        guard data.count == expectedSize else {
            throw .invalidDataSize(expected: expectedSize, actual: data.count)
        }

        self.width = width
        self.height = height
        self.data = data
    }

    /// Creates a MonoBitmap from unpacked pixel values.
    ///
    /// - Parameters:
    ///   - width: Width in pixels. Must be exactly 384.
    ///   - height: Height in pixels. Must be positive.
    ///   - pixels: Array of pixel values (0 = white, non-zero = black).
    ///             Size must equal width × height.
    /// - Throws: `MonoBitmapError` if parameters are invalid.
    init(width: Int, height: Int, pixels: [UInt8]) throws(MonoBitmapError) {
        guard width == PrinterConstants.printWidth else {
            throw .invalidWidth(width)
        }
        guard height > 0 else {
            throw .invalidHeight(height)
        }
        guard pixels.count == width * height else {
            throw .invalidPixelCount(expected: width * height, actual: pixels.count)
        }

        self.width = width
        self.height = height
        self.data = Self.packPixels(pixels, width: width, height: height)
    }

    /// Returns the packed byte data for a specific row.
    ///
    /// - Parameter index: Row index (0-based from top).
    /// - Returns: 48 bytes of packed pixel data for the row.
    /// - Precondition: `index < height`
    func row(at index: Int) -> Data {
        precondition(index >= 0 && index < height, "Row index out of bounds")
        let start = index * bytesPerRow
        let end = start + bytesPerRow
        return data[start..<end]
    }

    /// Returns the pixel value at the specified coordinates.
    ///
    /// - Parameters:
    ///   - x: X coordinate (0-based from left).
    ///   - y: Y coordinate (0-based from top).
    /// - Returns: `true` if the pixel is black, `false` if white.
    /// - Precondition: `x < width && y < height`
    func pixel(at x: Int, y: Int) -> Bool {
        precondition(x >= 0 && x < width, "X coordinate out of bounds")
        precondition(y >= 0 && y < height, "Y coordinate out of bounds")

        let byteIndex = y * bytesPerRow + (x / 8)
        let bitIndex = x % 8  // LSB first: bit 0 = leftmost
        let byte = data[data.startIndex + byteIndex]
        return (byte & (1 << bitIndex)) != 0
    }

    /// Packs unpacked pixel values into 1-bit packed data.
    ///
    /// - Parameters:
    ///   - pixels: Array of pixel values (0 = white, non-zero = black).
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    /// - Returns: Packed byte data.
    private static func packPixels(_ pixels: [UInt8], width: Int, height: Int) -> Data {
        let bytesPerRow = PrinterConstants.bytesPerRow
        var packedData = Data(count: height * bytesPerRow)

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let isBlack = pixels[pixelIndex] != 0

                if isBlack {
                    let byteIndex = y * bytesPerRow + (x / 8)
                    let bitIndex = x % 8  // LSB first: bit 0 = leftmost
                    packedData[byteIndex] |= UInt8(1 << bitIndex)
                }
            }
        }

        return packedData
    }
}

// MARK: - MonoBitmapError

/// Errors that can occur when creating a MonoBitmap.
enum MonoBitmapError: Error, Equatable, Sendable {
    /// Width must be exactly 384 pixels.
    case invalidWidth(Int)

    /// Height must be positive.
    case invalidHeight(Int)

    /// Data size doesn't match expected size.
    case invalidDataSize(expected: Int, actual: Int)

    /// Pixel array count doesn't match dimensions.
    case invalidPixelCount(expected: Int, actual: Int)
}

// MARK: - LocalizedError

extension MonoBitmapError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidWidth(let width):
            return "Invalid bitmap width: \(width). Must be exactly \(PrinterConstants.printWidth)."
        case .invalidHeight(let height):
            return "Invalid bitmap height: \(height). Must be positive."
        case .invalidDataSize(let expected, let actual):
            return "Invalid data size: expected \(expected) bytes, got \(actual)."
        case .invalidPixelCount(let expected, let actual):
            return "Invalid pixel count: expected \(expected), got \(actual)."
        }
    }
}
