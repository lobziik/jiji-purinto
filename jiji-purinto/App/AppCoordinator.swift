//
//  AppCoordinator.swift
//  jiji-purinto
//
//  Connects the FSM to SwiftUI views.
//

import SwiftUI
import Combine
import Photos
import os

/// Logger for app coordination.
private let appLogger = Logger(subsystem: "com.jiji-purinto", category: "AppCoordinator")

/// Coordinates application state and connects FSM to SwiftUI.
///
/// This class acts as the single source of truth for the application state.
/// It wraps the pure `AppFSM` and provides a reactive interface for SwiftUI views.
///
/// ## Usage
/// ```swift
/// @StateObject private var coordinator = AppCoordinator()
///
/// // Send events
/// try coordinator.send(.openCamera)
/// ```
@MainActor
final class AppCoordinator: ObservableObject {
    // MARK: - Published State

    /// Current application state.
    @Published private(set) var state: AppState = .idle

    /// The printer coordinator for managing printer connection and printing.
    let printerCoordinator = PrinterCoordinator()

    /// Whether the printer is connected and ready.
    ///
    /// This is used as a guard condition for the print transition.
    var printerReady: Bool {
        printerCoordinator.isReady
    }

    /// The original image before processing (for re-processing with new settings).
    @Published private(set) var originalImage: UIImage?

    /// The processed preview image for display.
    @Published private(set) var processedPreview: UIImage?

    /// Current processing settings (persisted between previews).
    @Published var imageSettings: ImageSettings = .default

    /// Whether settings sheet is being shown.
    @Published var showingSettings: Bool = false

    /// Whether image processing is in progress.
    @Published private(set) var isProcessing: Bool = false

    // MARK: - Private

    private let fsm = AppFSM()
    private let imageProcessor = ImageProcessor()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Subscribe to printer coordinator changes to trigger UI updates
        printerCoordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Subscribe to print interruption notifications
        printerCoordinator.onPrintInterrupted = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if case .printing = self.state {
                    let appError = AppError.printingFailed(reason: "Connection lost: \(error.localizedDescription)")
                    appLogger.error("Print interrupted by connection loss: \(error.localizedDescription)")
                    try? self.send(.printFailed(appError))
                }
            }
        }

        // Attempt to reconnect to last printer on launch
        Task {
            await printerCoordinator.reconnectToLast()
        }
    }

    // MARK: - Event Handling

    /// Sends an event to the FSM and updates the state.
    ///
    /// - Parameter event: The event to process.
    /// - Throws: `FSMError` if the transition is invalid or a guard fails.
    func send(_ event: AppEvent) throws {
        let fromState = state
        let context = FSMContext(printerReady: printerReady)
        let newState = try fsm.transition(from: state, event: event, context: context)
        appLogger.info("AppFSM: \(String(describing: fromState)) --[\(String(describing: event))]--> \(String(describing: newState))")
        state = newState
    }

    /// Attempts to send an event, logging failures explicitly.
    ///
    /// - Parameter event: The event to process.
    /// - Returns: `true` if the transition succeeded, `false` otherwise.
    ///
    /// - Note: Use this only for UI actions where failure is expected (e.g., back button).
    ///   For critical operations, use `send(_:)` and handle errors explicitly.
    @discardableResult
    func trySend(_ event: AppEvent) -> Bool {
        do {
            try send(event)
            return true
        } catch {
            appLogger.warning("AppFSM transition failed: \(String(describing: self.state)) --[\(String(describing: event))]--> REJECTED: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Convenience Methods

    /// Opens the gallery for image selection.
    func openGallery() throws {
        try send(.openGallery)
    }

    /// Cancels the current image selection.
    func cancelSelection() throws {
        try send(.cancelSelection)
    }

    /// Notifies that an image was selected.
    ///
    /// - Parameter image: The selected image.
    func imageSelected(_ image: UIImage) throws {
        try send(.imageSelected(image))
    }

    /// Notifies that image processing completed.
    ///
    /// - Parameter image: The processed preview image.
    func processingComplete(_ image: UIImage) throws {
        try send(.processingComplete(image))
    }

    /// Updates image processing settings.
    ///
    /// - Parameter settings: The new settings.
    func updateSettings(_ settings: ImageSettings) throws {
        try send(.settingsChanged(settings))
    }

    /// Initiates printing.
    ///
    /// - Throws: `FSMError.guardFailed` if the printer is not ready.
    func print() throws {
        try send(.print)
    }

    /// Updates print progress.
    ///
    /// - Parameter progress: Progress value from 0.0 to 1.0.
    func updatePrintProgress(_ progress: Float) throws {
        try send(.printProgress(progress))
    }

    /// Notifies that printing completed successfully.
    func printSuccess() throws {
        try send(.printSuccess)
    }

    /// Resets the app to the idle state.
    func reset() throws {
        try send(.reset)
        originalImage = nil
        processedPreview = nil
    }

    // MARK: - Image Processing

    /// Processes the selected image and transitions to preview state.
    ///
    /// - Parameter image: The selected image to process.
    func processImage(_ image: UIImage) async {
        originalImage = image
        isProcessing = true

        do {
            // Generate preview
            let preview = try await imageProcessor.quickPreview(
                image: image,
                settings: imageSettings,
                previewWidth: PrinterConstants.printWidth
            )

            processedPreview = preview

            // Transition to preview state
            try send(.processingComplete(preview))
        } catch let processingError as ProcessingError {
            // Transition to error state with specific processing error
            try? send(.processingFailed(.processingFailed(reason: processingError.localizedDescription)))
        } catch {
            // Transition to error state with unexpected error
            try? send(.processingFailed(.unexpected(error.localizedDescription)))
        }

        isProcessing = false
    }

    /// Returns the processed image at print resolution (384px) for sharing.
    ///
    /// Unlike the preview (which may use lower resolution for fast UI updates),
    /// this returns the full print-resolution dithered image suitable for export.
    ///
    /// - Returns: Dithered UIImage at print resolution.
    /// - Throws: `ProcessingError` if no image is selected or processing fails.
    func getShareableImage() async throws(ProcessingError) -> UIImage {
        guard let original = originalImage else {
            throw .invalidImage
        }

        return try await imageProcessor.quickPreview(
            image: original,
            settings: imageSettings,
            previewWidth: PrinterConstants.printWidth
        )
    }

    /// Re-processes the current image with updated settings.
    ///
    /// Called when settings change in the preview screen.
    func reprocessWithCurrentSettings() async {
        guard let image = originalImage else { return }

        isProcessing = true

        do {
            let preview = try await imageProcessor.quickPreview(
                image: image,
                settings: imageSettings,
                previewWidth: PrinterConstants.printWidth
            )

            processedPreview = preview

            // Update preview state with new image and settings
            try send(.settingsChanged(imageSettings))
        } catch {
            // Keep the old preview on error
        }

        isProcessing = false
    }

    /// Processes the image for printing and returns the MonoBitmap.
    ///
    /// - Returns: The processed MonoBitmap ready for printing.
    /// - Throws: `ProcessingError` if processing fails.
    func processForPrinting() async throws(ProcessingError) -> MonoBitmap {
        guard let image = originalImage else {
            throw .invalidImage
        }

        return try await imageProcessor.process(image: image, settings: imageSettings)
    }

    // MARK: - Debug: Test Patterns

    /// Prints a test pattern for printer diagnostics.
    ///
    /// Only available when `DebugConfig.enableDebugMenu` is true.
    /// Uses proper FSM state transitions to show printing progress and done screen.
    ///
    /// - Parameter pattern: The test pattern type to print.
    /// - Throws: `AppError` if printer not ready or print fails.
    func printTestPattern(_ pattern: TestPatternType) async throws(AppError) {
        guard printerReady else {
            throw .printerNotReady
        }

        let (data, height) = patternData(for: pattern)

        do {
            let bitmap = try PrinterTestPatterns.toMonoBitmap(data: data, height: height)
            try send(.print)
            try await printerCoordinator.print(bitmap: bitmap) { [weak self] progress in
                Task { @MainActor [weak self] in
                    try? self?.send(.printProgress(Float(progress)))
                }
            }
            try send(.printSuccess)
        } catch let error as PrinterError {
            try? send(.printFailed(.printingFailed(reason: error.localizedDescription)))
            throw .printingFailed(reason: error.localizedDescription)
        } catch let error as MonoBitmapError {
            throw .processingFailed(reason: error.localizedDescription)
        } catch let error as FSMError {
            throw .unexpected("State transition failed: \(error.localizedDescription)")
        } catch {
            throw .unexpected(error.localizedDescription)
        }
    }

    /// Returns the raw pattern data and height for a test pattern type.
    ///
    /// - Parameter pattern: The test pattern type.
    /// - Returns: Tuple of raw bitmap data and pattern height in rows.
    private func patternData(for pattern: TestPatternType) -> (Data, Int) {
        switch pattern {
        case .diagnosticAll:
            return PrinterTestPatterns.diagnosticPattern()
        case .verticalStripes:
            let data = PrinterTestPatterns.verticalStripes(height: 100)
            return (data, 100)
        case .horizontalStripes:
            let data = PrinterTestPatterns.horizontalStripes(height: 100)
            return (data, 100)
        case .checkerboard:
            let data = PrinterTestPatterns.checkerboard(height: 128)
            return (data, 128)
        case .checkerboard5cm:
            return PrinterTestPatterns.checkerboard5cm()
        case .leftBorder:
            let data = PrinterTestPatterns.leftBorder(height: 100)
            return (data, 100)
        case .rightBorder:
            let data = PrinterTestPatterns.rightBorder(height: 100)
            return (data, 100)
        case .arrow:
            let data = PrinterTestPatterns.arrow()
            return (data, 48)
        case .fullWidthLines:
            let data = PrinterTestPatterns.fullWidthLines()
            return (data, 75)  // 5 * (5 black + 10 white)
        case .singlePixelTest:
            let data = PrinterTestPatterns.singlePixelTest(height: 50)
            return (data, 50)
        }
    }

    /// Prints the current image.
    ///
    /// Processes the original image and sends it to the printer.
    ///
    /// - Throws: `AppError` if processing or printing fails.
    func printCurrentImage() async throws(AppError) {
        guard printerReady else {
            throw .printerNotReady
        }

        // Transition to printing state
        do {
            try send(.print)
        } catch {
            throw .unexpected("Failed to start printing: \(error.localizedDescription)")
        }

        // Process the image
        let bitmap: MonoBitmap
        do {
            bitmap = try await processForPrinting()
        } catch {
            let appError = AppError.processingFailed(reason: error.localizedDescription)
            try? send(.processingFailed(appError))
            throw appError
        }

        // Print the bitmap with progress updates
        do {
            try await printerCoordinator.print(bitmap: bitmap) { [weak self] progress in
                Task { @MainActor [weak self] in
                    try? self?.send(.printProgress(Float(progress)))
                }
            }
        } catch {
            let appError = AppError.printingFailed(reason: error.localizedDescription)
            try? send(.printFailed(appError))
            throw appError
        }

        // Transition to done state
        do {
            try send(.printSuccess)
        } catch {
            // Already printed successfully, ignore state transition error
        }
    }

    // MARK: - Debug: Save to Gallery

    /// Saves the processed MonoBitmap as a PNG to the photo gallery.
    ///
    /// Only available when `DebugConfig.enableDebugMenu` is true.
    /// Useful for inspecting the exact 1-bit image that would be sent to the printer.
    ///
    /// - Throws: `AppError` if processing or saving fails.
    func saveMonoBitmapToGallery() async throws(AppError) {
        // Process the image to get MonoBitmap
        let bitmap: MonoBitmap
        do {
            bitmap = try await processForPrinting()
        } catch {
            throw .processingFailed(reason: error.localizedDescription)
        }

        // Convert MonoBitmap to raw UIImage (no color transformations)
        let image: UIImage
        do {
            image = try await imageProcessor.bitmapToRawUIImage(bitmap)
        } catch {
            throw .processingFailed(reason: "Failed to convert bitmap to image")
        }

        // Request photo library access and save
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw .unexpected("Photo library access denied")
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }
        } catch {
            throw .unexpected("Failed to save image: \(error.localizedDescription)")
        }
    }
}

// MARK: - State Queries

extension AppCoordinator {
    /// Whether the app is currently showing an image picker.
    var isSelectingImage: Bool {
        if case .selecting = state {
            return true
        }
        return false
    }

    /// The current image source being selected, if any.
    var currentImageSource: ImageSource? {
        if case .selecting(let source) = state {
            return source
        }
        return nil
    }

    /// The current preview image, if in preview state.
    var previewImage: UIImage? {
        if case .preview(let image, _) = state {
            return image
        }
        return nil
    }

    /// The current image settings, if in preview state.
    var currentSettings: ImageSettings? {
        if case .preview(_, let settings) = state {
            return settings
        }
        return nil
    }

    /// The current print progress, if printing.
    var printProgress: Float? {
        if case .printing(let progress) = state {
            return progress
        }
        return nil
    }

    /// The current error, if in error state.
    var currentError: AppError? {
        if case .error(let error) = state {
            return error
        }
        return nil
    }
}
