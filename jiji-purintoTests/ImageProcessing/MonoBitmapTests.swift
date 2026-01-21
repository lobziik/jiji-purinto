//
//  MonoBitmapTests.swift
//  jiji-purintoTests
//
//  Tests for MonoBitmap bit packing and creation.
//

import Testing
import Foundation
@testable import jiji_purinto

/// Tests for MonoBitmap bit packing correctness.
@Suite("MonoBitmap Tests")
struct MonoBitmapTests {
    // MARK: - Creation Tests

    @Test("Creates bitmap with valid packed data")
    func createWithValidPackedData() throws {
        let height = 2
        let dataSize = height * PrinterConstants.bytesPerRow
        let data = Data(count: dataSize)

        let bitmap = try MonoBitmap(
            width: PrinterConstants.printWidth,
            height: height,
            data: data
        )

        #expect(bitmap.width == 384)
        #expect(bitmap.height == 2)
        #expect(bitmap.data.count == dataSize)
        #expect(bitmap.bytesPerRow == 48)
    }

    @Test("Creates bitmap from unpacked pixels")
    func createFromUnpackedPixels() throws {
        let width = PrinterConstants.printWidth
        let height = 2
        let pixels = [UInt8](repeating: 0, count: width * height)

        let bitmap = try MonoBitmap(width: width, height: height, pixels: pixels)

        #expect(bitmap.width == width)
        #expect(bitmap.height == height)
        #expect(bitmap.data.count == height * PrinterConstants.bytesPerRow)
    }

    // MARK: - Validation Tests

    @Test("Rejects invalid width")
    func rejectsInvalidWidth() {
        #expect(throws: MonoBitmapError.invalidWidth(100)) {
            _ = try MonoBitmap(
                width: 100,
                height: 10,
                data: Data(count: 10 * 48)
            )
        }
    }

    @Test("Rejects zero height")
    func rejectsZeroHeight() {
        #expect(throws: MonoBitmapError.invalidHeight(0)) {
            _ = try MonoBitmap(
                width: 384,
                height: 0,
                data: Data()
            )
        }
    }

    @Test("Rejects negative height")
    func rejectsNegativeHeight() {
        #expect(throws: MonoBitmapError.invalidHeight(-1)) {
            _ = try MonoBitmap(
                width: 384,
                height: -1,
                data: Data()
            )
        }
    }

    @Test("Rejects incorrect data size")
    func rejectsIncorrectDataSize() {
        #expect(throws: MonoBitmapError.invalidDataSize(expected: 96, actual: 50)) {
            _ = try MonoBitmap(
                width: 384,
                height: 2,
                data: Data(count: 50)
            )
        }
    }

    @Test("Rejects incorrect pixel count")
    func rejectsIncorrectPixelCount() {
        let pixels = [UInt8](repeating: 0, count: 100)

        #expect(throws: MonoBitmapError.invalidPixelCount(expected: 768, actual: 100)) {
            _ = try MonoBitmap(
                width: 384,
                height: 2,
                pixels: pixels
            )
        }
    }

    // MARK: - Bit Packing Tests

    @Test("Packs all-black pixels correctly")
    func packsAllBlackPixels() throws {
        let width = PrinterConstants.printWidth
        let height = 1
        // Non-zero = black
        let pixels = [UInt8](repeating: 255, count: width * height)

        let bitmap = try MonoBitmap(width: width, height: height, pixels: pixels)

        // All bytes should be 0xFF (all bits set = all black)
        for byte in bitmap.data {
            #expect(byte == 0xFF)
        }
    }

    @Test("Packs all-white pixels correctly")
    func packsAllWhitePixels() throws {
        let width = PrinterConstants.printWidth
        let height = 1
        // Zero = white
        let pixels = [UInt8](repeating: 0, count: width * height)

        let bitmap = try MonoBitmap(width: width, height: height, pixels: pixels)

        // All bytes should be 0x00 (no bits set = all white)
        for byte in bitmap.data {
            #expect(byte == 0x00)
        }
    }

    @Test("Packs single black pixel correctly (MSB first)")
    func packsSingleBlackPixelMSBFirst() throws {
        let width = PrinterConstants.printWidth
        let height = 1
        var pixels = [UInt8](repeating: 0, count: width * height)
        // First pixel is black
        pixels[0] = 255

        let bitmap = try MonoBitmap(width: width, height: height, pixels: pixels)

        // First byte should have MSB set (0x80 = 10000000)
        #expect(bitmap.data[0] == 0x80)

        // Rest should be white
        for i in 1..<bitmap.data.count {
            #expect(bitmap.data[i] == 0x00)
        }
    }

    @Test("Packs 8th pixel correctly (LSB)")
    func packs8thPixelLSB() throws {
        let width = PrinterConstants.printWidth
        let height = 1
        var pixels = [UInt8](repeating: 0, count: width * height)
        // 8th pixel (index 7) is black
        pixels[7] = 255

        let bitmap = try MonoBitmap(width: width, height: height, pixels: pixels)

        // First byte should have LSB set (0x01 = 00000001)
        #expect(bitmap.data[0] == 0x01)
    }

    @Test("Packs alternating pixels correctly")
    func packsAlternatingPixels() throws {
        let width = PrinterConstants.printWidth
        let height = 1
        var pixels = [UInt8](repeating: 0, count: width * height)

        // Set every other pixel to black (0, 2, 4, 6, ...)
        for i in stride(from: 0, to: width, by: 2) {
            pixels[i] = 255
        }

        let bitmap = try MonoBitmap(width: width, height: height, pixels: pixels)

        // Every byte should be 0xAA (10101010)
        for i in 0..<PrinterConstants.bytesPerRow {
            #expect(bitmap.data[i] == 0xAA)
        }
    }

    // MARK: - Pixel Access Tests

    @Test("Reads pixel values correctly")
    func readsPixelValuesCorrectly() throws {
        let width = PrinterConstants.printWidth
        let height = 2
        var pixels = [UInt8](repeating: 0, count: width * height)

        // Set specific pixels
        pixels[0] = 255       // First row, first pixel
        pixels[383] = 255     // First row, last pixel
        pixels[384] = 255     // Second row, first pixel

        let bitmap = try MonoBitmap(width: width, height: height, pixels: pixels)

        #expect(bitmap.pixel(at: 0, y: 0) == true)
        #expect(bitmap.pixel(at: 1, y: 0) == false)
        #expect(bitmap.pixel(at: 383, y: 0) == true)
        #expect(bitmap.pixel(at: 0, y: 1) == true)
        #expect(bitmap.pixel(at: 1, y: 1) == false)
    }

    // MARK: - Row Access Tests

    @Test("Returns correct row data")
    func returnsCorrectRowData() throws {
        let width = PrinterConstants.printWidth
        let height = 3
        var pixels = [UInt8](repeating: 0, count: width * height)

        // Fill second row with black
        for i in width..<(width * 2) {
            pixels[i] = 255
        }

        let bitmap = try MonoBitmap(width: width, height: height, pixels: pixels)

        let row0 = bitmap.row(at: 0)
        let row1 = bitmap.row(at: 1)
        let row2 = bitmap.row(at: 2)

        #expect(row0.count == 48)
        #expect(row1.count == 48)
        #expect(row2.count == 48)

        // Row 0 should be all white
        #expect(row0.allSatisfy { $0 == 0x00 })

        // Row 1 should be all black
        #expect(row1.allSatisfy { $0 == 0xFF })

        // Row 2 should be all white
        #expect(row2.allSatisfy { $0 == 0x00 })
    }

    // MARK: - Pixel Count Tests

    @Test("Reports correct pixel count")
    func reportsCorrectPixelCount() throws {
        let bitmap = try MonoBitmap(
            width: 384,
            height: 100,
            data: Data(count: 100 * 48)
        )

        #expect(bitmap.pixelCount == 38400)
    }
}
