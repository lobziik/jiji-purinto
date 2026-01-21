//
//  AppFSMGuardTests.swift
//  jiji-purintoTests
//
//  Tests for FSM guard conditions.
//

import Testing
import UIKit
@testable import jiji_purinto

/// Tests for guard conditions in AppFSM transitions.
@Suite("AppFSM Guard Conditions")
struct AppFSMGuardTests {
    let fsm = AppFSM()
    let testImage = UIImage()

    // MARK: - Print guard (printer ready)

    @Test("preview + print with printer NOT ready throws guardFailed")
    func preview_print_printerNotReady_throwsGuardFailed() {
        let context = FSMContext(printerReady: false)

        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .preview(image: testImage, settings: .default),
                event: .print,
                context: context
            )
        }
    }

    @Test("idle + print with printer NOT ready throws guardFailed")
    func idle_print_printerNotReady_throwsGuardFailed() {
        let context = FSMContext(printerReady: false)

        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .idle,
                event: .print,
                context: context
            )
        }
    }

    @Test("preview + print with default context throws guardFailed")
    func preview_print_defaultContext_throwsGuardFailed() {
        // Default context has printerReady = false
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(
                from: .preview(image: testImage, settings: .default),
                event: .print
            )
        }
    }

    @Test("preview + print with printer ready succeeds")
    func preview_print_printerReady_succeeds() throws {
        let context = FSMContext(printerReady: true)

        let next = try fsm.transition(
            from: .preview(image: testImage, settings: .default),
            event: .print,
            context: context
        )

        #expect(next == .printing(progress: 0))
    }

    @Test("guard failure has descriptive reason")
    func guardFailure_hasDescriptiveReason() {
        let context = FSMContext(printerReady: false)

        do {
            _ = try fsm.transition(
                from: .preview(image: testImage, settings: .default),
                event: .print,
                context: context
            )
            Issue.record("Expected guardFailed error")
        } catch let error as FSMError {
            if case .guardFailed(let reason) = error {
                #expect(reason.contains("not ready") || reason.contains("Printer"))
            } else {
                Issue.record("Expected guardFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected FSMError, got \(error)")
        }
    }
}
