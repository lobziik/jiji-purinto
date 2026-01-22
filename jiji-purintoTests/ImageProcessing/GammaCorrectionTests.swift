//
//  GammaCorrectionTests.swift
//  jiji-purintoTests
//
//  Tests for gamma correction.
//

import Testing
@testable import jiji_purinto

/// Tests for GammaCorrection.
@Suite("GammaCorrection Tests")
struct GammaCorrectionTests {
    @Test("Gamma 1.0 returns unchanged")
    func gammaOneUnchanged() {
        let pixels: [UInt8] = [0, 64, 128, 192, 255]

        let result = GammaCorrection.apply(to: pixels, gamma: 1.0)

        #expect(result == pixels)
    }

    @Test("Gamma > 1 brightens midtones")
    func gammaBrightens() {
        // Mid-gray value
        let pixels: [UInt8] = [128]

        let result = GammaCorrection.apply(to: pixels, gamma: 2.0)

        // Gamma > 1 should brighten midtones
        // Formula: output = 255 * (128/255)^(1/2) = 255 * sqrt(0.502) ≈ 181
        #expect(result[0] > pixels[0], "Gamma > 1 should brighten midtones")
        #expect(result[0] > 170 && result[0] < 190, "Mid-gray with gamma 2.0 should be around 181")
    }

    @Test("Gamma < 1 darkens midtones")
    func gammaDarkens() {
        // Mid-gray value
        let pixels: [UInt8] = [128]

        let result = GammaCorrection.apply(to: pixels, gamma: 0.8)

        // Gamma < 1 should darken midtones (but our range is 0.8-2.0, so 0.8 still darkens)
        #expect(result[0] < pixels[0], "Gamma < 1 should darken midtones")
    }

    @Test("Preserves black and white")
    func preservesExtremes() {
        let pixels: [UInt8] = [0, 255]

        // Test with various gamma values
        let result1 = GammaCorrection.apply(to: pixels, gamma: 0.8)
        let result2 = GammaCorrection.apply(to: pixels, gamma: 1.4)
        let result3 = GammaCorrection.apply(to: pixels, gamma: 2.0)

        // Black (0) should always stay 0
        #expect(result1[0] == 0)
        #expect(result2[0] == 0)
        #expect(result3[0] == 0)

        // White (255) should always stay 255
        #expect(result1[1] == 255)
        #expect(result2[1] == 255)
        #expect(result3[1] == 255)
    }

    @Test("Clamps invalid gamma")
    func clampsInvalidGamma() {
        let pixels: [UInt8] = [128]

        // Values below 0.8 should be clamped to 0.8
        let resultLow = GammaCorrection.apply(to: pixels, gamma: 0.1)
        let resultAt08 = GammaCorrection.apply(to: pixels, gamma: 0.8)

        // Values above 2.0 should be clamped to 2.0
        let resultHigh = GammaCorrection.apply(to: pixels, gamma: 5.0)
        let resultAt20 = GammaCorrection.apply(to: pixels, gamma: 2.0)

        // Clamped values should match boundary values
        #expect(resultLow[0] == resultAt08[0], "Gamma below 0.8 should clamp to 0.8")
        #expect(resultHigh[0] == resultAt20[0], "Gamma above 2.0 should clamp to 2.0")
    }

    @Test("Handles empty input")
    func handlesEmptyInput() {
        let result = GammaCorrection.apply(to: [], gamma: 1.4)
        #expect(result.isEmpty)
    }

    @Test("Preserves pixel count")
    func preservesPixelCount() {
        let pixels = [UInt8](repeating: 100, count: 1000)
        let result = GammaCorrection.apply(to: pixels, gamma: 1.4)
        #expect(result.count == pixels.count)
    }

    @Test("Output values stay in valid range")
    func outputValuesInRange() {
        // Various pixel values
        let pixels: [UInt8] = [0, 10, 50, 100, 150, 200, 250, 255]

        let result = GammaCorrection.apply(to: pixels, gamma: 1.4)

        for value in result {
            #expect(value >= 0 && value <= 255, "Output values must be in 0-255 range")
        }
    }

    @Test("Monotonically increasing for ascending input")
    func monotonicForAscending() {
        // Ascending pixel values
        let pixels: [UInt8] = [0, 50, 100, 150, 200, 255]

        let result = GammaCorrection.apply(to: pixels, gamma: 1.4)

        // Output should also be monotonically increasing
        for i in 1..<result.count {
            #expect(result[i] >= result[i - 1], "Gamma should preserve monotonicity")
        }
    }
}
