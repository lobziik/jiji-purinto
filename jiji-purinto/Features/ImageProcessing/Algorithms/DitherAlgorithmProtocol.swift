//
//  DitherAlgorithmProtocol.swift
//  jiji-purinto
//
//  Protocol and factory for dithering algorithms.
//

import Foundation

/// Protocol for dithering algorithms that convert grayscale to 1-bit.
///
/// Implementations convert 8-bit grayscale pixel data (0-255) to binary
/// (0 or 255) using various dithering techniques to simulate continuous tones.
protocol DitherAlgorithmProtocol: Sendable {
    /// Applies dithering to grayscale pixel data.
    ///
    /// - Parameters:
    ///   - pixels: Grayscale pixel values (0-255), row-major order.
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    /// - Returns: Binary pixel values (0 for white, 255 for black).
    func dither(pixels: [UInt8], width: Int, height: Int) -> [UInt8]
}

/// Factory for creating dithering algorithm instances.
enum DitherAlgorithmFactory {
    /// Creates a dithering algorithm instance for the given type.
    ///
    /// - Parameter algorithm: The algorithm type to create.
    /// - Returns: An instance conforming to `DitherAlgorithmProtocol`.
    static func create(for algorithm: DitherAlgorithm) -> DitherAlgorithmProtocol {
        switch algorithm {
        case .threshold:
            return ThresholdDither()
        case .floydSteinberg:
            return FloydSteinbergDither()
        case .atkinson:
            return AtkinsonDither()
        case .ordered:
            return OrderedDither()
        }
    }
}
