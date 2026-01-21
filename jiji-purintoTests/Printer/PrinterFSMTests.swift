//
//  PrinterFSMTests.swift
//  jiji-purintoTests
//
//  Tests for valid PrinterFSM transitions.
//

import Foundation
import Testing
@testable import jiji_purinto

/// Tests for valid state transitions in PrinterFSM.
@Suite("PrinterFSM Valid Transitions")
struct PrinterFSMTests {
    let fsm = PrinterFSM()
    let testPrinter = DiscoveredPrinter(id: UUID(), name: "Test Printer", rssi: -50)
    let testDeviceId = UUID()
    let testDeviceName = "Test Printer"

    // MARK: - From disconnected

    @Test("disconnected + startScan -> scanning")
    func disconnected_startScan_transitionsToScanning() throws {
        let next = try fsm.transition(from: .disconnected, event: .startScan)
        #expect(next == .scanning)
    }

    @Test("disconnected + reconnect -> connecting")
    func disconnected_reconnect_transitionsToConnecting() throws {
        let deviceId = UUID()
        let next = try fsm.transition(from: .disconnected, event: .reconnect(deviceId: deviceId))
        #expect(next == .connecting(deviceId: deviceId))
    }

    // MARK: - From scanning

    @Test("scanning + connect -> connecting")
    func scanning_connect_transitionsToConnecting() throws {
        let next = try fsm.transition(from: .scanning, event: .connect(printer: testPrinter))
        #expect(next == .connecting(deviceId: testPrinter.id))
    }

    @Test("scanning + cancelScan -> disconnected")
    func scanning_cancelScan_transitionsToDisconnected() throws {
        let next = try fsm.transition(from: .scanning, event: .cancelScan)
        #expect(next == .disconnected)
    }

    @Test("scanning + scanTimeout -> disconnected")
    func scanning_scanTimeout_transitionsToDisconnected() throws {
        let next = try fsm.transition(from: .scanning, event: .scanTimeout)
        #expect(next == .disconnected)
    }

    // MARK: - From connecting

    @Test("connecting + connectSuccess -> ready")
    func connecting_connectSuccess_transitionsToReady() throws {
        let next = try fsm.transition(
            from: .connecting(deviceId: testDeviceId),
            event: .connectSuccess(deviceId: testDeviceId, deviceName: testDeviceName)
        )
        #expect(next == .ready(deviceId: testDeviceId, deviceName: testDeviceName))
    }

    @Test("connecting + connectFailed -> error")
    func connecting_connectFailed_transitionsToError() throws {
        let error = PrinterError.connectionFailed(reason: "Test error")
        let next = try fsm.transition(
            from: .connecting(deviceId: testDeviceId),
            event: .connectFailed(error)
        )
        #expect(next == .error(error))
    }

    @Test("connecting + connectionLost -> error")
    func connecting_connectionLost_transitionsToError() throws {
        let next = try fsm.transition(
            from: .connecting(deviceId: testDeviceId),
            event: .connectionLost
        )
        #expect(next == .error(.connectionLost))
    }

    // MARK: - From ready

    @Test("ready + printStart -> busy")
    func ready_printStart_transitionsToBusy() throws {
        let next = try fsm.transition(
            from: .ready(deviceId: testDeviceId, deviceName: testDeviceName),
            event: .printStart
        )
        #expect(next == .busy(deviceId: testDeviceId))
    }

    @Test("ready + disconnect -> disconnected")
    func ready_disconnect_transitionsToDisconnected() throws {
        let next = try fsm.transition(
            from: .ready(deviceId: testDeviceId, deviceName: testDeviceName),
            event: .disconnect
        )
        #expect(next == .disconnected)
    }

    @Test("ready + connectionLost -> error")
    func ready_connectionLost_transitionsToError() throws {
        let next = try fsm.transition(
            from: .ready(deviceId: testDeviceId, deviceName: testDeviceName),
            event: .connectionLost
        )
        #expect(next == .error(.connectionLost))
    }

    // MARK: - From busy

    @Test("busy + printComplete -> ready")
    func busy_printComplete_transitionsToReady() throws {
        let next = try fsm.transition(
            from: .busy(deviceId: testDeviceId),
            event: .printComplete
        )
        if case .ready(let deviceId, _) = next {
            #expect(deviceId == testDeviceId)
        } else {
            Issue.record("Expected ready state")
        }
    }

    @Test("busy + printFailed -> error")
    func busy_printFailed_transitionsToError() throws {
        let error = PrinterError.printFailed(reason: "Paper jam")
        let next = try fsm.transition(
            from: .busy(deviceId: testDeviceId),
            event: .printFailed(error)
        )
        #expect(next == .error(error))
    }

    @Test("busy + connectionLost -> error")
    func busy_connectionLost_transitionsToError() throws {
        let next = try fsm.transition(
            from: .busy(deviceId: testDeviceId),
            event: .connectionLost
        )
        #expect(next == .error(.connectionLost))
    }

    // MARK: - From error

    @Test("error + reset -> disconnected")
    func error_reset_transitionsToDisconnected() throws {
        let next = try fsm.transition(
            from: .error(.connectionLost),
            event: .reset
        )
        #expect(next == .disconnected)
    }
}
