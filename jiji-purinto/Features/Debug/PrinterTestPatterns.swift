//
//  PrinterTestPatterns.swift
//  jiji-purinto
//
//  Test patterns for diagnosing thermal printer issues.
//

import Foundation

/// Test patterns for diagnosing thermal printer issues.
///
/// Each pattern helps identify specific problems:
/// - Vertical lines -> horizontal bit/byte order
/// - Horizontal lines -> vertical sync issues
/// - Checkerboard -> bit order (MSB vs LSB)
/// - Arrow -> orientation and mirroring
/// - Gradient -> overall alignment
enum PrinterTestPatterns {

    /// Print width in pixels (384 for Cat/MX printers).
    static let width = 384

    /// Print width in bytes (48 bytes = 384 bits).
    static let widthBytes = 48

    // MARK: - MonoBitmap Conversion

    /// Converts raw pattern data to MonoBitmap for printing.
    ///
    /// - Parameters:
    ///   - data: Raw bitmap data from pattern generator.
    ///   - height: Pattern height in rows.
    /// - Returns: MonoBitmap ready for printing.
    /// - Throws: `MonoBitmapError` if data is invalid.
    static func toMonoBitmap(data: Data, height: Int) throws(MonoBitmapError) -> MonoBitmap {
        try MonoBitmap(width: width, height: height, data: data)
    }

    // MARK: - Test Pattern 1: Vertical Stripes

    /// Creates vertical stripes pattern (alternating 8px black/white columns).
    ///
    /// Expected output: |   |   |   |   |   |
    /// If corrupted: horizontal bit order is wrong
    ///
    /// - Parameter height: Number of rows.
    /// - Returns: Raw bitmap data.
    static func verticalStripes(height: Int = 100) -> Data {
        // 0xAA = 10101010 in binary -> alternating pixels
        let row = Array(repeating: UInt8(0xAA), count: widthBytes)
        var data = Data()
        for _ in 0..<height {
            data.append(contentsOf: row)
        }
        return data
    }

    // MARK: - Test Pattern 2: Horizontal Stripes

    /// Creates horizontal stripes pattern (alternating black/white rows).
    ///
    /// Expected output: Alternating black and white horizontal lines
    /// If corrupted: vertical sync or feed issues
    ///
    /// - Parameter height: Number of rows (should be even).
    /// - Returns: Raw bitmap data.
    static func horizontalStripes(height: Int = 100) -> Data {
        let blackRow = Array(repeating: UInt8(0xFF), count: widthBytes)
        let whiteRow = Array(repeating: UInt8(0x00), count: widthBytes)
        var data = Data()
        for i in 0..<height {
            if i % 2 == 0 {
                data.append(contentsOf: blackRow)
            } else {
                data.append(contentsOf: whiteRow)
            }
        }
        return data
    }

    // MARK: - Test Pattern 3: Checkerboard

    /// Creates checkerboard pattern (8x8 pixel squares).
    ///
    /// Expected output: Chess board pattern
    /// If diagonal lines: bit order is inverted
    /// If vertical lines: byte order is wrong
    ///
    /// - Parameter height: Number of rows.
    /// - Returns: Raw bitmap data.
    static func checkerboard(height: Int = 128) -> Data {
        var data = Data()
        for y in 0..<height {
            var row = [UInt8]()
            let evenRow = (y / 8) % 2 == 0
            for x in 0..<widthBytes {
                let evenByte = x % 2 == 0
                if evenRow == evenByte {
                    row.append(0xFF)  // black byte
                } else {
                    row.append(0x00)  // white byte
                }
            }
            data.append(contentsOf: row)
        }
        return data
    }

    // MARK: - Test Pattern 3b: Checkerboard 5cm (Calibration)

    /// Creates a 5cm checkerboard calibration pattern with 2×2mm cells.
    ///
    /// Designed for geometry verification:
    /// - Cell size: 2×2mm = 16×16px (at 203 DPI = 8 px/mm)
    /// - Pattern height: 50mm = 400 rows
    /// - Pattern width: 384px = 48 bytes (full print width)
    /// - Total data: 400 rows × 48 bytes = 19,200 bytes
    ///
    /// Expected output: Perfect checkerboard with square 2mm cells.
    /// - If cells are rectangular: paper feed is miscalibrated
    /// - If diagonal stripes: bit order is inverted
    /// - If vertical stripes: byte order is wrong
    ///
    /// - Returns: Tuple of raw bitmap data and pattern height in rows.
    static func checkerboard5cm() -> (data: Data, height: Int) {
        let cellSize = 16  // 2mm × 8 px/mm = 16 pixels
        let patternHeight = 400  // 50mm × 8 px/mm = 400 rows

        var data = Data()
        data.reserveCapacity(patternHeight * widthBytes)

        for y in 0..<patternHeight {
            var row = [UInt8]()
            row.reserveCapacity(widthBytes)

            let cellY = y / cellSize

            for byteIndex in 0..<widthBytes {
                var byte: UInt8 = 0

                // Process each bit in the byte
                for bitIndex in 0..<8 {
                    let pixelX = byteIndex * 8 + bitIndex
                    let cellX = pixelX / cellSize

                    // Checkerboard pattern: black cell when (cellY % 2) != (cellX % 2)
                    let isBlackCell = (cellY % 2) != (cellX % 2)

                    if isBlackCell {
                        // MSB first: bit 7 is leftmost pixel
                        byte |= (1 << (7 - bitIndex))
                    }
                }

                row.append(byte)
            }

            data.append(contentsOf: row)
        }

        return (data, patternHeight)
    }

    // MARK: - Test Pattern 4: Left Border

    /// Creates pattern with black bar on LEFT side only.
    ///
    /// Expected output: Black bar on LEFT edge
    /// If on right: byte order is reversed
    /// If scattered: bit order issues
    ///
    /// - Parameter height: Number of rows.
    /// - Returns: Raw bitmap data.
    static func leftBorder(height: Int = 100) -> Data {
        var row = Array(repeating: UInt8(0x00), count: widthBytes)
        // First 4 bytes = 32 pixels on LEFT
        row[0] = 0xFF
        row[1] = 0xFF
        row[2] = 0xFF
        row[3] = 0xFF

        var data = Data()
        for _ in 0..<height {
            data.append(contentsOf: row)
        }
        return data
    }

    // MARK: - Test Pattern 5: Right Border

    /// Creates pattern with black bar on RIGHT side only.
    ///
    /// Expected output: Black bar on RIGHT edge
    /// Compare with leftBorder to diagnose byte order
    ///
    /// - Parameter height: Number of rows.
    /// - Returns: Raw bitmap data.
    static func rightBorder(height: Int = 100) -> Data {
        var row = Array(repeating: UInt8(0x00), count: widthBytes)
        // Last 4 bytes = 32 pixels on RIGHT
        row[44] = 0xFF
        row[45] = 0xFF
        row[46] = 0xFF
        row[47] = 0xFF

        var data = Data()
        for _ in 0..<height {
            data.append(contentsOf: row)
        }
        return data
    }

    // MARK: - Test Pattern 6: Arrow (->)

    /// Creates a right-pointing arrow.
    ///
    /// Expected output: Arrow pointing RIGHT ->
    /// If pointing left: horizontal flip
    /// If pointing up/down: 90 deg rotation issue
    ///
    /// - Returns: Raw bitmap data.
    static func arrow() -> Data {
        let h = 48  // arrow height
        var data = Data()

        for y in 0..<h {
            var row = Array(repeating: UInt8(0x00), count: widthBytes)

            // Arrow shaft (horizontal line in middle)
            if y >= 20 && y < 28 {
                for x in 8..<32 {
                    row[x] = 0xFF
                }
            }

            // Arrow head (triangle on right)
            let distFromCenter = abs(y - 24)
            if distFromCenter < 20 {
                let headWidth = 20 - distFromCenter
                for x in 32..<(32 + headWidth / 4 + 1) {
                    if x < widthBytes {
                        row[x] = 0xFF
                    }
                }
            }

            data.append(contentsOf: row)
        }

        return data
    }

    // MARK: - Test Pattern 7: Gradient (numbered columns)

    /// Creates numbered column markers.
    ///
    /// Shows byte positions: |0|1|2|...|47|
    /// Helps identify which bytes are misaligned
    ///
    /// - Parameter height: Number of rows.
    /// - Returns: Raw bitmap data.
    static func gradientColumns(height: Int = 50) -> Data {
        var data = Data()

        for y in 0..<height {
            var row = [UInt8]()
            for x in 0..<widthBytes {
                // Create gradient: each byte slightly different
                // Byte 0 = 0x80 (one pixel), Byte 47 = full
                let density = UInt8((x * 255) / widthBytes)
                if y % 10 < 5 {
                    row.append(density)
                } else {
                    row.append(0x00)  // gap between gradient bands
                }
            }
            data.append(contentsOf: row)
        }

        return data
    }

    // MARK: - Test Pattern 8: Single Pixel Columns

    /// Creates single pixel at specific positions.
    ///
    /// Tests: bit position within byte (MSB vs LSB)
    /// Expected: dots at positions 0, 8, 16, 24... (byte boundaries)
    ///
    /// - Parameter height: Number of rows.
    /// - Returns: Raw bitmap data.
    static func singlePixelTest(height: Int = 50) -> Data {
        var data = Data()

        for y in 0..<height {
            var row = Array(repeating: UInt8(0x00), count: widthBytes)

            // MSB test: 0x80 = bit 7 set = leftmost pixel in byte
            // LSB test: 0x01 = bit 0 set = rightmost pixel in byte

            if y < height / 2 {
                // First half: MSB (0x80) - should be LEFT pixel of each byte
                for x in stride(from: 0, to: widthBytes, by: 4) {
                    row[x] = 0x80
                }
            } else {
                // Second half: LSB (0x01) - should be RIGHT pixel of each byte
                for x in stride(from: 0, to: widthBytes, by: 4) {
                    row[x] = 0x01
                }
            }

            data.append(contentsOf: row)
        }

        return data
    }

    // MARK: - Test Pattern 9: Full Width Line

    /// Creates full-width black lines with gaps.
    ///
    /// Tests: all 384 pixels printing correctly
    /// Look for any gaps or missing sections
    ///
    /// - Returns: Raw bitmap data.
    static func fullWidthLines() -> Data {
        let blackRow = Array(repeating: UInt8(0xFF), count: widthBytes)
        let whiteRow = Array(repeating: UInt8(0x00), count: widthBytes)

        var data = Data()

        // 5 black lines, 10 white, repeat
        for _ in 0..<5 {
            for _ in 0..<5 {
                data.append(contentsOf: blackRow)
            }
            for _ in 0..<10 {
                data.append(contentsOf: whiteRow)
            }
        }

        return data
    }

    // MARK: - All-in-One Diagnostic

    /// Creates combined test pattern with all diagnostics.
    ///
    /// Sections from top to bottom:
    /// 1. Full width lines (alignment)
    /// 2. Left border (byte order)
    /// 3. Right border (byte order)
    /// 4. Vertical stripes (bit pattern)
    /// 5. Checkerboard (bit order)
    /// 6. Single pixel test (MSB/LSB)
    ///
    /// - Returns: Raw bitmap data and total height.
    static func diagnosticPattern() -> (data: Data, height: Int) {
        var data = Data()

        // Section 1: Full width lines (30 rows)
        data.append(fullWidthLines())

        // Gap
        data.append(contentsOf: Array(repeating: UInt8(0x00), count: widthBytes * 20))

        // Section 2: Left border (30 rows)
        data.append(leftBorder(height: 30))

        // Gap
        data.append(contentsOf: Array(repeating: UInt8(0x00), count: widthBytes * 10))

        // Section 3: Right border (30 rows)
        data.append(rightBorder(height: 30))

        // Gap
        data.append(contentsOf: Array(repeating: UInt8(0x00), count: widthBytes * 10))

        // Section 4: Vertical stripes (40 rows)
        data.append(verticalStripes(height: 40))

        // Gap
        data.append(contentsOf: Array(repeating: UInt8(0x00), count: widthBytes * 10))

        // Section 5: Checkerboard (48 rows)
        data.append(checkerboard(height: 48))

        // Gap
        data.append(contentsOf: Array(repeating: UInt8(0x00), count: widthBytes * 10))

        // Section 6: Single pixel test (40 rows)
        data.append(singlePixelTest(height: 40))

        // Final gap
        data.append(contentsOf: Array(repeating: UInt8(0x00), count: widthBytes * 30))

        let height = data.count / widthBytes
        return (data, height)
    }
}
