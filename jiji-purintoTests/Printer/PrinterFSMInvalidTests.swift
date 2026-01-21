//
//  PrinterFSMInvalidTests.swift
//  jiji-purintoTests
//
//  Tests for invalid PrinterFSM transitions.
//

import Foundation
import Testing
@testable import jiji_purinto

/// Tests for invalid state transitions in PrinterFSM.
///
/// These tests verify that invalid transitions throw FSMError.invalidTransition.
@Suite("PrinterFSM Invalid Transitions")
struct PrinterFSMInvalidTests {
    let fsm = PrinterFSM()
    let testPrinter = DiscoveredPrinter(id: UUID(), name: "Test Printer", rssi: -50)
    let testDeviceId = UUID()
    let testDeviceName = "Test Printer"

    // MARK: - From disconnected

    @Test("disconnected + connect throws")
    func disconnected_connect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .disconnected, event: .connect(printer: testPrinter))
        }
    }

    @Test("disconnected + printStart throws")
    func disconnected_printStart_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .disconnected, event: .printStart)
        }
    }

    @Test("disconnected + disconnect throws")
    func disconnected_disconnect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .disconnected, event: .disconnect)
        }
    }

    // MARK: - From scanning

    @Test("scanning + startScan throws")
    func scanning_startScan_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .scanning, event: .startScan)
        }
    }

    @Test("scanning + printStart throws")
    func scanning_printStart_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .scanning, event: .printStart)
        }
    }

    @Test("scanning + disconnect throws")
    func scanning_disconnect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .scanning, event: .disconnect)
        }
    }

    // MARK: - From connecting

    @Test("connecting + startScan throws")
    func connecting_startScan_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .connecting(deviceId: testDeviceId), event: .startScan)
        }
    }

    @Test("connecting + printStart throws")
    func connecting_printStart_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .connecting(deviceId: testDeviceId), event: .printStart)
        }
    }

    @Test("connecting + disconnect throws")
    func connecting_disconnect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .connecting(deviceId: testDeviceId), event: .disconnect)
        }
    }

    // MARK: - From ready

    @Test("ready + startScan throws")
    func ready_startScan_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .ready(deviceId: testDeviceId, deviceName: testDeviceName),
                event: .startScan
            )
        }
    }

    @Test("ready + connect throws")
    func ready_connect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .ready(deviceId: testDeviceId, deviceName: testDeviceName),
                event: .connect(printer: testPrinter)
            )
        }
    }

    @Test("ready + printComplete throws")
    func ready_printComplete_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .ready(deviceId: testDeviceId, deviceName: testDeviceName),
                event: .printComplete
            )
        }
    }

    // MARK: - From busy

    @Test("busy + startScan throws")
    func busy_startScan_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .busy(deviceId: testDeviceId), event: .startScan)
        }
    }

    @Test("busy + connect throws")
    func busy_connect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .busy(deviceId: testDeviceId), event: .connect(printer: testPrinter))
        }
    }

    @Test("busy + printStart throws")
    func busy_printStart_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .busy(deviceId: testDeviceId), event: .printStart)
        }
    }

    @Test("busy + disconnect throws")
    func busy_disconnect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .busy(deviceId: testDeviceId), event: .disconnect)
        }
    }

    // MARK: - From error

    @Test("error + startScan throws")
    func error_startScan_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .error(.connectionLost), event: .startScan)
        }
    }

    @Test("error + connect throws")
    func error_connect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .error(.connectionLost), event: .connect(printer: testPrinter))
        }
    }

    @Test("error + printStart throws")
    func error_printStart_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .error(.connectionLost), event: .printStart)
        }
    }

    @Test("error + disconnect throws")
    func error_disconnect_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .error(.connectionLost), event: .disconnect)
        }
    }
}
