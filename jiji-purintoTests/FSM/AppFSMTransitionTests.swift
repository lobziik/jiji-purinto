//
//  AppFSMTransitionTests.swift
//  jiji-purintoTests
//
//  Tests for valid FSM transitions.
//

import Testing
import UIKit
@testable import jiji_purinto

/// Tests for valid state transitions in AppFSM.
@Suite("AppFSM Valid Transitions")
struct AppFSMTransitionTests {
    let fsm = AppFSM()
    let testImage = UIImage()

    // MARK: - From idle

    @Test("idle + openGallery -> selecting(.gallery)")
    func idle_openGallery_transitionsToSelectingGallery() throws {
        let next = try fsm.transition(from: .idle, event: .openGallery)
        #expect(next == .selecting(source: .gallery))
    }

    @Test("idle + print (printer ready) -> printing (for debug test patterns)")
    func idle_print_printerReady_transitionsToPrinting() throws {
        let context = FSMContext(printerReady: true)
        let next = try fsm.transition(from: .idle, event: .print, context: context)
        #expect(next == .printing(progress: 0))
    }

    // MARK: - From selecting

    @Test("selecting + imageSelected -> processing")
    func selecting_imageSelected_transitionsToProcessing() throws {
        let next = try fsm.transition(
            from: .selecting(source: .gallery),
            event: .imageSelected(testImage)
        )
        #expect(next == .processing)
    }

    @Test("selecting + imageSelectionFailed -> error")
    func selecting_imageSelectionFailed_transitionsToError() throws {
        let error = AppError.cancelled
        let next = try fsm.transition(
            from: .selecting(source: .gallery),
            event: .imageSelectionFailed(error)
        )
        #expect(next == .error(error))
    }

    @Test("selecting + cancelSelection -> idle")
    func selecting_cancelSelection_transitionsToIdle() throws {
        let next = try fsm.transition(
            from: .selecting(source: .gallery),
            event: .cancelSelection
        )
        #expect(next == .idle)
    }

    // MARK: - From processing

    @Test("processing + processingComplete -> preview")
    func processing_processingComplete_transitionsToPreview() throws {
        let next = try fsm.transition(
            from: .processing,
            event: .processingComplete(testImage)
        )
        if case .preview(_, let settings) = next {
            #expect(settings == .default)
        } else {
            Issue.record("Expected preview state")
        }
    }

    @Test("processing + processingFailed -> error")
    func processing_processingFailed_transitionsToError() throws {
        let error = AppError.processingFailed(reason: "test")
        let next = try fsm.transition(
            from: .processing,
            event: .processingFailed(error)
        )
        #expect(next == .error(error))
    }

    // MARK: - From preview

    @Test("preview + settingsChanged -> preview with new settings")
    func preview_settingsChanged_updatesSettings() throws {
        let initialState = AppState.preview(image: testImage, settings: .default)
        let newSettings = ImageSettings(
            brightness: 0.5,
            contrast: 1.5,
            algorithm: .atkinson,
            gamma: 1.4,
            autoLevels: true,
            clipPercent: 1.0
        )

        let next = try fsm.transition(from: initialState, event: .settingsChanged(newSettings))

        if case .preview(_, let settings) = next {
            #expect(settings == newSettings)
        } else {
            Issue.record("Expected preview state")
        }
    }

    @Test("preview + openGallery -> selecting(.gallery)")
    func preview_openGallery_transitionsToSelecting() throws {
        let next = try fsm.transition(
            from: .preview(image: testImage, settings: .default),
            event: .openGallery
        )
        #expect(next == .selecting(source: .gallery))
    }

    @Test("preview + reset -> idle")
    func preview_reset_transitionsToIdle() throws {
        let next = try fsm.transition(
            from: .preview(image: testImage, settings: .default),
            event: .reset
        )
        #expect(next == .idle)
    }

    @Test("preview + print (printer ready) -> printing")
    func preview_print_printerReady_transitionsToPrinting() throws {
        let context = FSMContext(printerReady: true)
        let next = try fsm.transition(
            from: .preview(image: testImage, settings: .default),
            event: .print,
            context: context
        )
        #expect(next == .printing(progress: 0))
    }

    // MARK: - From printing

    @Test("printing + printProgress -> printing with updated progress")
    func printing_printProgress_updatesProgress() throws {
        let next = try fsm.transition(
            from: .printing(progress: 0.3),
            event: .printProgress(0.7)
        )
        #expect(next == .printing(progress: 0.7))
    }

    @Test("printing + printSuccess -> done")
    func printing_printSuccess_transitionsToDone() throws {
        let next = try fsm.transition(
            from: .printing(progress: 0.99),
            event: .printSuccess
        )
        #expect(next == .done)
    }

    @Test("printing + printFailed -> error")
    func printing_printFailed_transitionsToError() throws {
        let error = AppError.printingFailed(reason: "Paper jam")
        let next = try fsm.transition(
            from: .printing(progress: 0.5),
            event: .printFailed(error)
        )
        #expect(next == .error(error))
    }

    // MARK: - From done

    @Test("done + reset -> idle")
    func done_reset_transitionsToIdle() throws {
        let next = try fsm.transition(from: .done, event: .reset)
        #expect(next == .idle)
    }

    @Test("done + openGallery -> selecting(.gallery)")
    func done_openGallery_transitionsToSelecting() throws {
        let next = try fsm.transition(from: .done, event: .openGallery)
        #expect(next == .selecting(source: .gallery))
    }

    // MARK: - From error

    @Test("error + reset -> idle")
    func error_reset_transitionsToIdle() throws {
        let next = try fsm.transition(
            from: .error(.cancelled),
            event: .reset
        )
        #expect(next == .idle)
    }
}
