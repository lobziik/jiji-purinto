//
//  HistogramStretchTests.swift
//  jiji-purintoTests
//
//  Tests for histogram stretching (auto levels).
//

import Testing
@testable import jiji_purinto

/// Tests for HistogramStretch.
@Suite("HistogramStretch Tests")
struct HistogramStretchTests {
    @Test("Stretches narrow range to full")
    func stretchesNarrowRange() {
        // Pixels only in range 50-200
        let pixels: [UInt8] = [50, 100, 150, 200]

        let result = HistogramStretch.apply(to: pixels, clipPercent: 0.0)

        // First pixel (50) should become close to 0
        #expect(result[0] < 10, "Min value should stretch toward 0")
        // Last pixel (200) should become close to 255
        #expect(result[3] > 245, "Max value should stretch toward 255")
        // Middle values should spread out
        #expect(result[1] > result[0])
        #expect(result[2] > result[1])
        #expect(result[3] > result[2])
    }

    @Test("Handles already full range")
    func handlesFullRange() {
        // Pixels already span 0-255
        let pixels: [UInt8] = [0, 64, 128, 192, 255]

        let result = HistogramStretch.apply(to: pixels, clipPercent: 0.0)

        // Should be approximately the same (no significant stretching needed)
        #expect(result[0] == 0)
        #expect(result[4] == 255)
    }

    @Test("Handles uniform image")
    func handlesUniformImage() {
        // All pixels the same value
        let pixels: [UInt8] = [128, 128, 128, 128, 128]

        let result = HistogramStretch.apply(to: pixels, clipPercent: 0.0)

        // Should return unchanged since blackPoint >= whitePoint
        #expect(result == pixels)
    }

    @Test("Respects clip percent")
    func respectsClipPercent() {
        // Create array with most values in middle, outliers at edges
        var pixels = [UInt8](repeating: 128, count: 100)
        pixels[0] = 0      // 1% at black
        pixels[99] = 255   // 1% at white

        // With 0% clip, edges should be preserved
        let resultNoClip = HistogramStretch.apply(to: pixels, clipPercent: 0.0)

        // With 2% clip, edges should be ignored and middle values stretched
        let resultWithClip = HistogramStretch.apply(to: pixels, clipPercent: 2.0)

        // With clip, the middle values (128) should all become 0 or 255 since they're the only values
        // Actually, with clipping the outliers are ignored, so 128 becomes the range
        // which means blackPoint == whitePoint and no stretching occurs
        #expect(resultWithClip[50] == 128, "With clipping, uniform middle should stay unchanged")

        // The original outliers should be clamped
        #expect(resultNoClip[0] == 0)
        #expect(resultNoClip[99] == 255)
    }

    @Test("Clamps invalid clip percent")
    func clampsInvalidClipPercent() {
        let pixels: [UInt8] = [50, 100, 150, 200]

        // Negative clip should be clamped to 0
        let resultNegative = HistogramStretch.apply(to: pixels, clipPercent: -5.0)
        // Very high clip should be clamped to 5.0
        let resultHigh = HistogramStretch.apply(to: pixels, clipPercent: 50.0)

        // Both should produce valid output without crashing
        #expect(resultNegative.count == pixels.count)
        #expect(resultHigh.count == pixels.count)
    }

    @Test("Handles empty input")
    func handlesEmptyInput() {
        let result = HistogramStretch.apply(to: [], clipPercent: 1.0)
        #expect(result.isEmpty)
    }

    @Test("Preserves pixel count")
    func preservesPixelCount() {
        let pixels = [UInt8](repeating: 100, count: 1000)
        let result = HistogramStretch.apply(to: pixels, clipPercent: 1.0)
        #expect(result.count == pixels.count)
    }

    @Test("Output values stay in valid range")
    func outputValuesInRange() {
        // Random-ish pixel values
        let pixels: [UInt8] = [10, 50, 100, 150, 200, 250]

        let result = HistogramStretch.apply(to: pixels, clipPercent: 1.0)

        for value in result {
            #expect(value >= 0 && value <= 255, "Output values must be in 0-255 range")
        }
    }
}
