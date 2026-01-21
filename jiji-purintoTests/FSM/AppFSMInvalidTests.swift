//
//  AppFSMInvalidTests.swift
//  jiji-purintoTests
//
//  Tests for invalid FSM transitions that should throw.
//

import Testing
import UIKit
@testable import jiji_purinto

/// Tests that invalid transitions throw FSMError.invalidTransition.
@Suite("AppFSM Invalid Transitions")
struct AppFSMInvalidTests {
    let fsm = AppFSM()
    let testImage = UIImage()

    // MARK: - From idle

    @Test("idle + print throws invalidTransition")
    func idle_print_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .idle, event: .print)
        }
    }

    @Test("idle + printSuccess throws invalidTransition")
    func idle_printSuccess_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .idle, event: .printSuccess)
        }
    }

    @Test("idle + reset throws invalidTransition")
    func idle_reset_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .idle, event: .reset)
        }
    }

    @Test("idle + cancelSelection throws invalidTransition")
    func idle_cancelSelection_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .idle, event: .cancelSelection)
        }
    }

    // MARK: - From selecting

    @Test("selecting + print throws invalidTransition")
    func selecting_print_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .selecting(source: .camera),
                event: .print
            )
        }
    }

    @Test("selecting + openCamera throws invalidTransition")
    func selecting_openCamera_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .selecting(source: .gallery),
                event: .openCamera
            )
        }
    }

    // MARK: - From processing

    @Test("processing + print throws invalidTransition")
    func processing_print_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .processing, event: .print)
        }
    }

    @Test("processing + openCamera throws invalidTransition")
    func processing_openCamera_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .processing, event: .openCamera)
        }
    }

    @Test("processing + reset throws invalidTransition")
    func processing_reset_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .processing, event: .reset)
        }
    }

    // MARK: - From preview

    @Test("preview + cancelSelection throws invalidTransition")
    func preview_cancelSelection_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .preview(image: testImage, settings: .default),
                event: .cancelSelection
            )
        }
    }

    @Test("preview + printSuccess throws invalidTransition")
    func preview_printSuccess_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .preview(image: testImage, settings: .default),
                event: .printSuccess
            )
        }
    }

    // MARK: - From printing

    @Test("printing + openCamera throws invalidTransition")
    func printing_openCamera_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .printing(progress: 0.5),
                event: .openCamera
            )
        }
    }

    @Test("printing + reset throws invalidTransition")
    func printing_reset_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .printing(progress: 0.5),
                event: .reset
            )
        }
    }

    @Test("printing + print throws invalidTransition")
    func printing_print_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .printing(progress: 0.5),
                event: .print
            )
        }
    }

    // MARK: - From done

    @Test("done + print throws invalidTransition")
    func done_print_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .done, event: .print)
        }
    }

    @Test("done + printProgress throws invalidTransition")
    func done_printProgress_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .done, event: .printProgress(0.5))
        }
    }

    // MARK: - From error

    @Test("error + print throws invalidTransition")
    func error_print_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .error(.cancelled), event: .print)
        }
    }

    @Test("error + openCamera throws invalidTransition")
    func error_openCamera_throwsInvalidTransition() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .error(.cancelled), event: .openCamera)
        }
    }
}
