//
//  CatMXCommandsTests.swift
//  jiji-purintoTests
//
//  Tests for CatMX printer command building.
//

import Foundation
import Testing
@testable import jiji_purinto

/// Tests for CatMX command packet building.
///
/// Command format: [0x51, 0x78] [cmd] [00] [length_low] [length_high] [data...] [crc] [0xFF]
@Suite("CatMX Commands")
struct CatMXCommandsTests {

    // MARK: - Command Format Tests

    @Test("Commands have correct prefix")
    func commands_haveCorrectPrefix() {
        let cmd = CatMXCommands.getStatus()
        let bytes = Array(cmd)

        #expect(bytes[0] == 0x51)
        #expect(bytes[1] == 0x78)
    }

    @Test("Commands end with 0xFF")
    func commands_endWithFF() {
        let cmd = CatMXCommands.getStatus()
        let bytes = Array(cmd)

        #expect(bytes.last == 0xFF)
    }

    @Test("Commands have correct length encoding")
    func commands_haveCorrectLengthEncoding() {
        // feedPaper with 20 lines has 2 bytes of data
        let cmd = CatMXCommands.feedPaper(lines: 20)
        let bytes = Array(cmd)

        // Length is at bytes 4 (low) and 5 (high)
        let length = Int(bytes[4]) | (Int(bytes[5]) << 8)
        #expect(length == 2)
    }

    // MARK: - Specific Command Tests

    @Test("setQuality builds correct command")
    func setQuality_buildsCorrectCommand() {
        let cmd = CatMXCommands.setQuality(.normal)
        let bytes = Array(cmd)

        // [0x51, 0x78, 0xA4, 0x00, 0x01, 0x00, 0x32, crc, 0xFF]
        #expect(bytes[2] == CatMXConstants.Command.setQuality.rawValue)
        #expect(bytes[6] == CatMXConstants.Quality.normal.rawValue)
    }

    @Test("setEnergy builds correct command")
    func setEnergy_buildsCorrectCommand() {
        let energy: UInt8 = 0x70
        let cmd = CatMXCommands.setEnergy(energy)
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.setEnergy.rawValue)
        #expect(bytes[6] == energy)
    }

    @Test("feedPaper builds correct command with little-endian length")
    func feedPaper_buildsCorrectCommand() {
        let lines: UInt16 = 300 // 0x012C
        let cmd = CatMXCommands.feedPaper(lines: lines)
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.feedPaper.rawValue)
        // Data bytes: low byte first (little-endian)
        #expect(bytes[6] == 0x2C) // Low byte of 300
        #expect(bytes[7] == 0x01) // High byte of 300
    }

    @Test("startPrint builds correct command with row count")
    func startPrint_buildsCorrectCommand() {
        let rows: UInt16 = 500 // 0x01F4
        let cmd = CatMXCommands.startPrint(totalRows: rows)
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.startPrint.rawValue)
        #expect(bytes[6] == 0xF4) // Low byte of 500
        #expect(bytes[7] == 0x01) // High byte of 500
    }

    @Test("printLine includes row data")
    func printLine_includesRowData() {
        let rowData: [UInt8] = Array(repeating: 0xAA, count: 48) // 48 bytes
        let cmd = CatMXCommands.printLine(rowData: rowData)
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.printLine.rawValue)

        // Data length should be 48
        let length = Int(bytes[4]) | (Int(bytes[5]) << 8)
        #expect(length == 48)

        // Row data starts at byte 6
        for i in 0..<48 {
            #expect(bytes[6 + i] == 0xAA)
        }
    }

    @Test("endPrint builds correct command")
    func endPrint_buildsCorrectCommand() {
        let cmd = CatMXCommands.endPrint()
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.endPrint.rawValue)
        // No data, so length should be 0
        let length = Int(bytes[4]) | (Int(bytes[5]) << 8)
        #expect(length == 0)
    }

    @Test("getStatus builds correct command")
    func getStatus_buildsCorrectCommand() {
        let cmd = CatMXCommands.getStatus()
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.getStatus.rawValue)
    }

    // MARK: - CRC Tests

    @Test("CRC is calculated correctly")
    func crc_isCalculatedCorrectly() {
        let cmd = CatMXCommands.getStatus()
        let bytes = Array(cmd)

        // CRC is XOR of bytes from cmd (index 2) to end of data (before CRC and 0xFF)
        var expectedCRC: UInt8 = 0
        for i in 2..<(bytes.count - 2) {
            expectedCRC ^= bytes[i]
        }

        let actualCRC = bytes[bytes.count - 2]
        #expect(actualCRC == expectedCRC)
    }

    // MARK: - Status Parsing Tests

    @Test("parseStatusResponse extracts status byte")
    func parseStatusResponse_extractsStatusByte() {
        // Build a mock status response
        // [0x51, 0x78, 0xA7, 0x00, 0x01, 0x00, status, crc, 0xFF]
        var response: [UInt8] = [0x51, 0x78, 0xA7, 0x00, 0x01, 0x00, 0x00]

        // Calculate CRC
        var crc: UInt8 = 0
        for i in 2..<response.count {
            crc ^= response[i]
        }
        response.append(crc)
        response.append(0xFF)

        let status = CatMXCommands.parseStatusResponse(Data(response))
        #expect(status == 0x00)
    }

    @Test("parseStatusResponse returns nil for invalid data")
    func parseStatusResponse_returnsNilForInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02])
        let status = CatMXCommands.parseStatusResponse(invalidData)
        #expect(status == nil)
    }

    // MARK: - Error Detection Tests

    @Test("errorFromStatus detects paper error")
    func errorFromStatus_detectsPaperError() {
        let status: UInt8 = CatMXConstants.StatusBit.paperError.rawValue
        let error = CatMXCommands.errorFromStatus(status)
        #expect(error == .outOfPaper)
    }

    @Test("errorFromStatus detects overheat")
    func errorFromStatus_detectsOverheat() {
        let status: UInt8 = CatMXConstants.StatusBit.overheat.rawValue
        let error = CatMXCommands.errorFromStatus(status)
        #expect(error == .overheated)
    }

    @Test("errorFromStatus detects low battery")
    func errorFromStatus_detectsLowBattery() {
        let status: UInt8 = CatMXConstants.StatusBit.lowBattery.rawValue
        let error = CatMXCommands.errorFromStatus(status)
        #expect(error == .lowBattery)
    }

    @Test("errorFromStatus returns nil for ready status")
    func errorFromStatus_returnsNilForReady() {
        let status: UInt8 = CatMXConstants.StatusBit.ready.rawValue
        let error = CatMXCommands.errorFromStatus(status)
        #expect(error == nil)
    }
}
