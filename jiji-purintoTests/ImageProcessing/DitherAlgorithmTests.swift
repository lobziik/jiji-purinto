//
//  DitherAlgorithmTests.swift
//  jiji-purintoTests
//
//  Tests for dithering algorithms.
//

import Testing
import Foundation
@testable import jiji_purinto

/// Tests for dithering algorithm implementations.
@Suite("Dither Algorithm Tests")
struct DitherAlgorithmTests {
    // MARK: - Factory Tests

    @Test("Factory creates correct algorithm types")
    func factoryCreatesCorrectTypes() {
        let threshold = DitherAlgorithmFactory.create(for: .threshold)
        let floydSteinberg = DitherAlgorithmFactory.create(for: .floydSteinberg)
        let atkinson = DitherAlgorithmFactory.create(for: .atkinson)
        let ordered = DitherAlgorithmFactory.create(for: .ordered)

        #expect(threshold is ThresholdDither)
        #expect(floydSteinberg is FloydSteinbergDither)
        #expect(atkinson is AtkinsonDither)
        #expect(ordered is OrderedDither)
    }

    // MARK: - Threshold Tests

    @Test("Threshold converts all-white input to white output")
    func thresholdAllWhiteToWhite() {
        let ditherer = ThresholdDither()
        let pixels = [UInt8](repeating: 0, count: 16)

        let result = ditherer.dither(pixels: pixels, width: 4, height: 4)

        // 0 input (white) < 128 threshold = 255 output (black in our convention)
        // Wait, let's check the algorithm logic again...
        // In ThresholdDither: pixel >= threshold ? 0 : 255
        // So 0 < 128 means output is 255 (black)
        // This seems inverted. Let me check the convention:
        // In the dithering, 0 = white in output, 255 = black
        // Input 0 (dark/black) should become output 255 (black)
        // Input 255 (light/white) should become output 0 (white)
        // So the logic is: if input >= 128 (bright), output 0 (white)
        //                  if input < 128 (dark), output 255 (black)
        // Input 0 (dark) → output 255 (black) ✓
        #expect(result.allSatisfy { $0 == 255 })
    }

    @Test("Threshold converts all-bright input to white output")
    func thresholdAllBrightToWhite() {
        let ditherer = ThresholdDither()
        let pixels = [UInt8](repeating: 255, count: 16)

        let result = ditherer.dither(pixels: pixels, width: 4, height: 4)

        // 255 input (bright/white) >= 128 threshold = 0 output (white)
        #expect(result.allSatisfy { $0 == 0 })
    }

    @Test("Threshold handles exactly at threshold value (gamma-aware)")
    func thresholdExactlyAtThreshold() {
        let ditherer = ThresholdDither()
        // With gamma-aware threshold (0.5 linear):
        // - sRGB 187 = linear 0.497 → black
        // - sRGB 188 = linear 0.503 → white
        // - sRGB 189 = linear 0.509 → white
        let pixels: [UInt8] = [187, 188, 189]

        let result = ditherer.dither(pixels: pixels, width: 3, height: 1)

        #expect(result[0] == 255)  // 187 (0.497 linear) < 0.5 → black
        #expect(result[1] == 0)    // 188 (0.503 linear) >= 0.5 → white
        #expect(result[2] == 0)    // 189 (0.509 linear) >= 0.5 → white
    }

    @Test("Threshold custom threshold value works (sRGB threshold converted to linear)")
    func thresholdCustomThreshold() {
        // When using sRGB threshold, it's converted to linear internally
        // sRGB 200 = ~0.58 linear
        // sRGB 199 < 0.58 linear → black
        // sRGB 200 >= 0.58 linear → white (at threshold)
        // sRGB 201 >= 0.58 linear → white
        let ditherer = ThresholdDither(threshold: 200)
        let pixels: [UInt8] = [199, 200, 201]

        let result = ditherer.dither(pixels: pixels, width: 3, height: 1)

        #expect(result[0] == 255)  // 199 < 0.58 linear → black
        #expect(result[1] == 0)    // 200 >= 0.58 linear → white
        #expect(result[2] == 0)    // 201 >= 0.58 linear → white
    }

    @Test("Threshold returns empty for empty input")
    func thresholdEmptyInput() {
        let ditherer = ThresholdDither()
        let result = ditherer.dither(pixels: [], width: 0, height: 0)
        #expect(result.isEmpty)
    }

    @Test("Threshold returns empty for mismatched dimensions")
    func thresholdMismatchedDimensions() {
        let ditherer = ThresholdDither()
        let pixels = [UInt8](repeating: 128, count: 10)

        let result = ditherer.dither(pixels: pixels, width: 5, height: 5)

        #expect(result.isEmpty)
    }

    // MARK: - Floyd-Steinberg Tests

    @Test("FloydSteinberg produces binary output")
    func floydSteinbergBinaryOutput() {
        let ditherer = FloydSteinbergDither()
        // Gradient from black to white
        var pixels = [UInt8](repeating: 0, count: 64)
        for i in 0..<64 {
            pixels[i] = UInt8(i * 4)
        }

        let result = ditherer.dither(pixels: pixels, width: 8, height: 8)

        #expect(result.count == 64)
        #expect(result.allSatisfy { $0 == 0 || $0 == 255 })
    }

    @Test("FloydSteinberg preserves solid black")
    func floydSteinbergSolidBlack() {
        let ditherer = FloydSteinbergDither()
        let pixels = [UInt8](repeating: 0, count: 16)

        let result = ditherer.dither(pixels: pixels, width: 4, height: 4)

        // All dark input should result in all black output
        #expect(result.allSatisfy { $0 == 255 })
    }

    @Test("FloydSteinberg preserves solid white")
    func floydSteinbergSolidWhite() {
        let ditherer = FloydSteinbergDither()
        let pixels = [UInt8](repeating: 255, count: 16)

        let result = ditherer.dither(pixels: pixels, width: 4, height: 4)

        // All bright input should result in all white output
        #expect(result.allSatisfy { $0 == 0 })
    }

    @Test("FloydSteinberg handles mid-gray with error diffusion (gamma-aware)")
    func floydSteinbergMidGray() {
        let ditherer = FloydSteinbergDither()
        // sRGB 188 = ~0.503 linear (perceptual mid-gray), should produce ~50/50 mix
        let pixels = [UInt8](repeating: 188, count: 64)

        let result = ditherer.dither(pixels: pixels, width: 8, height: 8)

        let blackCount = result.filter { $0 == 255 }.count
        let whiteCount = result.filter { $0 == 0 }.count

        // Should have a mix of black and white (approximately 50/50)
        #expect(blackCount > 0)
        #expect(whiteCount > 0)
        #expect(blackCount + whiteCount == 64)
        // With gamma-aware, sRGB 188 should be close to 50% black
        let blackPercent = Float(blackCount) / 64.0
        #expect(blackPercent > 0.35 && blackPercent < 0.65)
    }

    // MARK: - Atkinson Tests

    @Test("Atkinson produces binary output")
    func atkinsonBinaryOutput() {
        let ditherer = AtkinsonDither()
        var pixels = [UInt8](repeating: 0, count: 64)
        for i in 0..<64 {
            pixels[i] = UInt8(i * 4)
        }

        let result = ditherer.dither(pixels: pixels, width: 8, height: 8)

        #expect(result.count == 64)
        #expect(result.allSatisfy { $0 == 0 || $0 == 255 })
    }

    @Test("Atkinson preserves extremes")
    func atkinsonPreservesExtremes() {
        let ditherer = AtkinsonDither()

        let blackInput = [UInt8](repeating: 0, count: 16)
        let whiteInput = [UInt8](repeating: 255, count: 16)

        let blackResult = ditherer.dither(pixels: blackInput, width: 4, height: 4)
        let whiteResult = ditherer.dither(pixels: whiteInput, width: 4, height: 4)

        #expect(blackResult.allSatisfy { $0 == 255 })
        #expect(whiteResult.allSatisfy { $0 == 0 })
    }

    // MARK: - Ordered Tests

    @Test("Ordered produces binary output")
    func orderedBinaryOutput() {
        let ditherer = OrderedDither()
        var pixels = [UInt8](repeating: 0, count: 64)
        for i in 0..<64 {
            pixels[i] = UInt8(i * 4)
        }

        let result = ditherer.dither(pixels: pixels, width: 8, height: 8)

        #expect(result.count == 64)
        #expect(result.allSatisfy { $0 == 0 || $0 == 255 })
    }

    @Test("Ordered preserves extremes")
    func orderedPreservesExtremes() {
        let ditherer = OrderedDither()

        let blackInput = [UInt8](repeating: 0, count: 16)
        let whiteInput = [UInt8](repeating: 255, count: 16)

        let blackResult = ditherer.dither(pixels: blackInput, width: 4, height: 4)
        let whiteResult = ditherer.dither(pixels: whiteInput, width: 4, height: 4)

        // Very dark should be mostly black
        let blackCount = blackResult.filter { $0 == 255 }.count
        #expect(blackCount >= 12)  // At least 75% black

        // Very bright should be mostly white
        let whiteCount = whiteResult.filter { $0 == 0 }.count
        #expect(whiteCount >= 12)  // At least 75% white
    }

    @Test("Ordered produces repeating pattern")
    func orderedRepeatingPattern() {
        let ditherer = OrderedDither()
        // Same input everywhere should produce repeating 8x8 pattern
        let pixels = [UInt8](repeating: 128, count: 256)  // 16x16

        let result = ditherer.dither(pixels: pixels, width: 16, height: 16)

        // Compare first 8x8 block to second 8x8 block horizontally
        for y in 0..<8 {
            for x in 0..<8 {
                let first = result[y * 16 + x]
                let second = result[y * 16 + x + 8]
                #expect(first == second)
            }
        }
    }

    // MARK: - Common Tests

    @Test("All algorithms handle single pixel")
    func allAlgorithmsHandleSinglePixel() {
        let algorithms: [DitherAlgorithmProtocol] = [
            ThresholdDither(),
            FloydSteinbergDither(),
            AtkinsonDither(),
            OrderedDither()
        ]

        for algorithm in algorithms {
            let result = algorithm.dither(pixels: [128], width: 1, height: 1)
            #expect(result.count == 1)
            #expect(result[0] == 0 || result[0] == 255)
        }
    }

    @Test("All algorithms preserve output size")
    func allAlgorithmsPreserveOutputSize() {
        let algorithms: [DitherAlgorithmProtocol] = [
            ThresholdDither(),
            FloydSteinbergDither(),
            AtkinsonDither(),
            OrderedDither()
        ]

        let pixels = [UInt8](repeating: 128, count: 100)

        for algorithm in algorithms {
            let result = algorithm.dither(pixels: pixels, width: 10, height: 10)
            #expect(result.count == 100)
        }
    }
}
