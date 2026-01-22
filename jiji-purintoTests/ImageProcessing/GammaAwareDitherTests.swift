//
//  GammaAwareDitherTests.swift
//  jiji-purintoTests
//
//  Tests for gamma-aware dithering algorithms.
//
//  These tests verify that dithering operates correctly in linear color space,
//  ensuring perceptually correct tone reproduction. Key insight:
//  - sRGB 128 is NOT 50% brightness (it's ~22% linear)
//  - sRGB 186 IS approximately 50% brightness in linear space
//
//  Reference: https://www.nayuki.io/page/gamma-aware-image-dithering
//

import Testing
import Foundation
@testable import jiji_purinto

/// Tests for gamma-aware dithering implementations.
///
/// Verifies that dark areas (sRGB 128) stay predominantly dark, and that
/// true perceptual middle gray (sRGB ~186) produces approximately 50% dots.
@Suite("Gamma-Aware Dither Tests")
struct GammaAwareDitherTests {
    // MARK: - Floyd-Steinberg Gamma Tests

    @Test("FloydSteinberg: sRGB 128 produces >70% black (gamma-aware)")
    func floydSteinberg_darkGrayProducesMoreBlack() {
        let ditherer = FloydSteinbergDither()
        // sRGB 128 = ~22% linear brightness, should be mostly black
        let pixels = [UInt8](repeating: 128, count: 10000)
        let result = ditherer.dither(pixels: pixels, width: 100, height: 100)

        let blackCount = result.filter { $0 == 255 }.count
        let blackPercent = Float(blackCount) / Float(result.count)

        // sRGB 128 is dark (~22% linear), so should be >70% black
        #expect(blackPercent > 0.70, "sRGB 128 should produce >70% black pixels, got \(blackPercent * 100)%")
    }

    @Test("FloydSteinberg: sRGB 188 produces ~50% black (perceptual middle gray)")
    func floydSteinberg_midGrayProducesFiftyPercent() {
        let ditherer = FloydSteinbergDither()
        // sRGB 188 = ~50% linear brightness (0.5028), should be ~50% black
        let pixels = [UInt8](repeating: 188, count: 10000)
        let result = ditherer.dither(pixels: pixels, width: 100, height: 100)

        let blackCount = result.filter { $0 == 255 }.count
        let blackPercent = Float(blackCount) / Float(result.count)

        // Should be approximately 50% (allow 45-55% range)
        #expect(blackPercent > 0.45 && blackPercent < 0.55,
                "sRGB 188 should produce ~50% black pixels, got \(blackPercent * 100)%")
    }

    // MARK: - Atkinson Gamma Tests

    @Test("Atkinson: sRGB 128 produces >65% black (gamma-aware)")
    func atkinson_darkGrayProducesMoreBlack() {
        let ditherer = AtkinsonDither()
        // sRGB 128 = ~22% linear brightness
        // Atkinson discards 2/8 of error, so may have slightly different distribution
        let pixels = [UInt8](repeating: 128, count: 10000)
        let result = ditherer.dither(pixels: pixels, width: 100, height: 100)

        let blackCount = result.filter { $0 == 255 }.count
        let blackPercent = Float(blackCount) / Float(result.count)

        // sRGB 128 is dark, should be >65% black (Atkinson is slightly less accurate)
        #expect(blackPercent > 0.65, "sRGB 128 should produce >65% black pixels, got \(blackPercent * 100)%")
    }

    @Test("Atkinson: sRGB 188 produces ~50% black")
    func atkinson_midGrayProducesFiftyPercent() {
        let ditherer = AtkinsonDither()
        // sRGB 188 = ~50% linear brightness
        let pixels = [UInt8](repeating: 188, count: 10000)
        let result = ditherer.dither(pixels: pixels, width: 100, height: 100)

        let blackCount = result.filter { $0 == 255 }.count
        let blackPercent = Float(blackCount) / Float(result.count)

        // Atkinson discards error, so allow wider range (40-60%)
        #expect(blackPercent > 0.40 && blackPercent < 0.60,
                "sRGB 188 should produce ~50% black pixels, got \(blackPercent * 100)%")
    }

    // MARK: - Threshold Gamma Tests

    @Test("Threshold: sRGB 128 produces 100% black (gamma-aware)")
    func threshold_darkGrayProducesAllBlack() {
        let ditherer = ThresholdDither()
        // sRGB 128 = ~22% linear, well below 0.5 threshold
        let pixels = [UInt8](repeating: 128, count: 100)
        let result = ditherer.dither(pixels: pixels, width: 10, height: 10)

        // All pixels should be black (255)
        #expect(result.allSatisfy { $0 == 255 },
                "sRGB 128 should produce all black pixels with gamma-aware threshold")
    }

    @Test("Threshold: sRGB 188 produces 100% white (at perceptual midpoint)")
    func threshold_midGrayProducesAllWhite() {
        let ditherer = ThresholdDither()
        // sRGB 188 = ~0.503 linear, just above 0.5 threshold
        let pixels = [UInt8](repeating: 188, count: 100)
        let result = ditherer.dither(pixels: pixels, width: 10, height: 10)

        // All pixels should be white (0) since 188 is above the threshold
        #expect(result.allSatisfy { $0 == 0 },
                "sRGB 188 should produce all white pixels with gamma-aware threshold")
    }

    @Test("Threshold: boundary behavior at perceptual midpoint")
    func threshold_boundaryBehavior() {
        let ditherer = ThresholdDither()
        // True crossover: sRGB 187 = 0.497 linear (BLACK), sRGB 188 = 0.503 linear (WHITE)
        let belowMid = [UInt8](repeating: 187, count: 10)
        let aboveMid = [UInt8](repeating: 188, count: 10)

        let belowResult = ditherer.dither(pixels: belowMid, width: 10, height: 1)
        let aboveResult = ditherer.dither(pixels: aboveMid, width: 10, height: 1)

        // 187 should be black, 188 should be white
        #expect(belowResult.allSatisfy { $0 == 255 }, "sRGB 187 (linear 0.497) should be black")
        #expect(aboveResult.allSatisfy { $0 == 0 }, "sRGB 188 (linear 0.503) should be white")
    }

    // MARK: - Ordered Gamma Tests

    @Test("Ordered: sRGB 128 produces >70% black (gamma-aware)")
    func ordered_darkGrayProducesMoreBlack() {
        let ditherer = OrderedDither()
        // sRGB 128 = ~22% linear, so should produce ~78% black (1 - 0.22)
        let pixels = [UInt8](repeating: 128, count: 256)  // 16x16 for full Bayer pattern
        let result = ditherer.dither(pixels: pixels, width: 16, height: 16)

        let blackCount = result.filter { $0 == 255 }.count
        let blackPercent = Float(blackCount) / Float(result.count)

        // With uniform linear thresholds, sRGB 128 (linear 0.216) should be ~78% black
        #expect(blackPercent > 0.70, "sRGB 128 should produce >70% black pixels, got \(blackPercent * 100)%")
    }

    @Test("Ordered: sRGB 188 produces ~50% black")
    func ordered_midGrayProducesFiftyPercent() {
        let ditherer = OrderedDither()
        // sRGB 188 = ~50% linear brightness
        let pixels = [UInt8](repeating: 188, count: 256)  // 16x16
        let result = ditherer.dither(pixels: pixels, width: 16, height: 16)

        let blackCount = result.filter { $0 == 255 }.count
        let blackPercent = Float(blackCount) / Float(result.count)

        // Allow reasonable range for ordered dithering
        #expect(blackPercent > 0.40 && blackPercent < 0.60,
                "sRGB 188 should produce ~50% black pixels, got \(blackPercent * 100)%")
    }

    // MARK: - Regression Tests (ensure existing behavior still works)

    @Test("Error diffusion algorithms: solid black input produces all black output")
    func errorDiffusion_solidBlackPreserved() {
        // Error diffusion algorithms should preserve solid black
        let algorithms: [DitherAlgorithmProtocol] = [
            FloydSteinbergDither(),
            AtkinsonDither(),
            ThresholdDither()
        ]

        for algorithm in algorithms {
            let pixels = [UInt8](repeating: 0, count: 64)  // 8x8 solid black
            let result = algorithm.dither(pixels: pixels, width: 8, height: 8)
            #expect(result.allSatisfy { $0 == 255 }, "Solid black should remain black")
        }
    }

    @Test("Ordered dither: solid black produces mostly black (>98%)")
    func ordered_solidBlackMostlyPreserved() {
        // Ordered dithering has one position where threshold = 0, so 0 >= 0 = white
        // This means 1/64 = ~1.5% of pixels may be white for solid black input
        let ditherer = OrderedDither()
        let pixels = [UInt8](repeating: 0, count: 64)  // 8x8 solid black
        let result = ditherer.dither(pixels: pixels, width: 8, height: 8)

        let blackCount = result.filter { $0 == 255 }.count
        let blackPercent = Float(blackCount) / Float(result.count)

        // Allow for 1/64 white pixels
        #expect(blackPercent > 0.98, "Solid black should be >98% black, got \(blackPercent * 100)%")
    }

    @Test("All algorithms: solid white input produces all white output")
    func allAlgorithms_solidWhitePreserved() {
        let algorithms: [DitherAlgorithmProtocol] = [
            FloydSteinbergDither(),
            AtkinsonDither(),
            ThresholdDither(),
            OrderedDither()
        ]

        for algorithm in algorithms {
            let pixels = [UInt8](repeating: 255, count: 64)  // 8x8 solid white
            let result = algorithm.dither(pixels: pixels, width: 8, height: 8)
            #expect(result.allSatisfy { $0 == 0 }, "Solid white should remain white")
        }
    }

    // MARK: - sRGB to Linear Conversion Verification

    @Test("Verify sRGB to linear conversion constants")
    func verifySrgbToLinearConversion() {
        // sRGB 0 -> linear 0
        // sRGB 128 -> linear ~0.216 (not 0.5!)
        // sRGB 188 -> linear ~0.503 (just above 0.5)
        // sRGB 255 -> linear 1.0

        // These values can be computed:
        // For sRGB 128: ((128/255 + 0.055) / 1.055)^2.4 ≈ 0.216
        // For sRGB 188: ((188/255 + 0.055) / 1.055)^2.4 ≈ 0.503

        let srgb128Linear: Float = {
            let x: Float = 128.0 / 255.0
            return powf((x + 0.055) / 1.055, 2.4)
        }()

        let srgb188Linear: Float = {
            let x: Float = 188.0 / 255.0
            return powf((x + 0.055) / 1.055, 2.4)
        }()

        // sRGB 128 should be approximately 0.216 (definitely less than 0.5)
        #expect(srgb128Linear > 0.20 && srgb128Linear < 0.25,
                "sRGB 128 should convert to ~0.216 linear, got \(srgb128Linear)")

        // sRGB 188 should be approximately 0.5 (just above)
        #expect(srgb188Linear > 0.50 && srgb188Linear < 0.52,
                "sRGB 188 should convert to ~0.503 linear, got \(srgb188Linear)")
    }
}
