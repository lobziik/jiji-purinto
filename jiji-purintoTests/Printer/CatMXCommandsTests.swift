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

    @Test("setSpeed builds correct command")
    func setSpeed_buildsCorrectCommand() {
        let speed: UInt8 = 32
        let cmd = CatMXCommands.setSpeed(speed)
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.setSpeed.rawValue)
        #expect(bytes[6] == speed)
    }

    @Test("applyEnergy builds correct command")
    func applyEnergy_buildsCorrectCommand() {
        let cmd = CatMXCommands.applyEnergy()
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.applyEnergy.rawValue)
        // applyEnergy sends 0x01 as data
        #expect(bytes[6] == 0x01)
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

    @Test("retract builds correct command")
    func retract_buildsCorrectCommand() {
        let lines: UInt16 = 10
        let cmd = CatMXCommands.retract(lines: lines)
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.retract.rawValue)
        #expect(bytes[6] == 0x0A) // Low byte of 10
        #expect(bytes[7] == 0x00) // High byte of 10
    }

    @Test("getStatus builds correct command")
    func getStatus_buildsCorrectCommand() {
        let cmd = CatMXCommands.getStatus()
        let bytes = Array(cmd)

        #expect(bytes[2] == CatMXConstants.Command.getStatus.rawValue)
    }

    // MARK: - CRC Tests

    @Test("CRC8 is calculated correctly for empty payload")
    func crc8_emptyPayload_returnsZero() {
        // For empty payload, CRC8 should be 0x00
        let cmd = CatMXCommands.getStatus()
        let bytes = Array(cmd)

        // CRC is calculated only on payload data, which is empty for getStatus
        // CRC8 of empty data is 0x00
        let actualCRC = bytes[bytes.count - 2]
        #expect(actualCRC == 0x00)
    }

    @Test("CRC8 matches TypeScript reference implementation")
    func crc8_matchesTypeScriptReference() {
        // Test with known values - verify CRC8 polynomial 0x07 algorithm
        // setEnergy(0x60) should produce a specific CRC
        let cmd = CatMXCommands.setEnergy(0x60)
        let bytes = Array(cmd)

        // Manually calculate CRC8 with polynomial 0x07 for payload [0x60]
        // Starting crc = 0, byte = 0x60 = 0110_0000
        // crc ^= 0x60 -> crc = 0x60
        // bit 7: crc=0x60, (crc & 0x80)=0, crc = 0xC0
        // bit 6: crc=0xC0, (crc & 0x80)≠0, crc = (0xC0 << 1) ^ 0x07 = 0x80 ^ 0x07 = 0x87
        // bit 5: crc=0x87, (crc & 0x80)≠0, crc = (0x87 << 1) ^ 0x07 = 0x0E ^ 0x07 = 0x09
        // bit 4: crc=0x09, (crc & 0x80)=0, crc = 0x12
        // bit 3: crc=0x12, (crc & 0x80)=0, crc = 0x24
        // bit 2: crc=0x24, (crc & 0x80)=0, crc = 0x48
        // bit 1: crc=0x48, (crc & 0x80)=0, crc = 0x90
        // bit 0: crc=0x90, (crc & 0x80)≠0, crc = (0x90 << 1) ^ 0x07 = 0x20 ^ 0x07 = 0x27
        let expectedCRC: UInt8 = 0x27
        let actualCRC = bytes[bytes.count - 2]
        #expect(actualCRC == expectedCRC)
    }

    @Test("CRC8 calculated on payload only, not command bytes")
    func crc8_payloadOnly() {
        // Two commands with same payload should have same CRC
        // regardless of the command byte
        let energyCmd = CatMXCommands.setEnergy(0x55)
        let speedCmd = CatMXCommands.setSpeed(0x55)

        let energyBytes = Array(energyCmd)
        let speedBytes = Array(speedCmd)

        // CRCs should match since both have same payload [0x55]
        let energyCRC = energyBytes[energyBytes.count - 2]
        let speedCRC = speedBytes[speedBytes.count - 2]
        #expect(energyCRC == speedCRC)
    }

    // MARK: - Status Parsing Tests

    @Test("parseStatusResponse extracts status byte")
    func parseStatusResponse_extractsStatusByte() {
        // Build a mock status response
        // [0x51, 0x78, 0xA3, 0x00, 0x01, 0x00, status, crc, 0xFF]
        // Note: getStatus command ID is 0xA3
        let response: [UInt8] = [0x51, 0x78, 0xA3, 0x00, 0x01, 0x00, 0x00, 0x00, 0xFF]

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
