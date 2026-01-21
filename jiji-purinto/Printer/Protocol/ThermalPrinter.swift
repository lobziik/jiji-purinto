//
//  ThermalPrinter.swift
//  jiji-purinto
//
//  Protocol defining the interface for thermal printer drivers.
//

import Foundation

/// Protocol defining the interface for thermal printer drivers.
///
/// Implementations handle the specifics of communicating with different
/// printer models while providing a consistent API for the app.
protocol ThermalPrinter: AnyObject {
    /// The device ID of the connected printer, if connected.
    var deviceId: UUID? { get }

    /// The name of the connected printer, if connected.
    var deviceName: String? { get }

    /// Whether the printer is currently connected.
    var isConnected: Bool { get }

    /// Scans for available printers.
    ///
    /// - Parameter timeout: Maximum time to scan in seconds.
    /// - Returns: Array of discovered printers.
    /// - Throws: `PrinterError` if scan fails.
    func scan(timeout: TimeInterval) async throws(PrinterError) -> [DiscoveredPrinter]

    /// Scans for available printers with reactive streaming.
    ///
    /// Yields discovered printers immediately as they are found,
    /// rather than waiting for the full timeout.
    ///
    /// - Parameter timeout: Maximum time to scan in seconds.
    /// - Returns: An async throwing stream of discovered printers.
    func scanStream(timeout: TimeInterval) -> AsyncThrowingStream<DiscoveredPrinter, Error>

    /// Connects to a discovered printer.
    ///
    /// - Parameter printer: The printer to connect to.
    /// - Throws: `PrinterError` if connection fails.
    func connect(to printer: DiscoveredPrinter) async throws(PrinterError)

    /// Disconnects from the current printer.
    func disconnect() async

    /// Prints a bitmap image.
    ///
    /// - Parameters:
    ///   - bitmap: The 1-bit bitmap to print.
    ///   - onProgress: Callback invoked with progress (0.0 to 1.0) during printing.
    /// - Throws: `PrinterError` if printing fails.
    func print(bitmap: MonoBitmap, onProgress: @escaping (Double) -> Void) async throws(PrinterError)
}

/// Default implementation for common operations.
extension ThermalPrinter {
    /// Prints a bitmap without progress reporting.
    ///
    /// - Parameter bitmap: The bitmap to print.
    /// - Throws: `PrinterError` if printing fails.
    func print(bitmap: MonoBitmap) async throws(PrinterError) {
        try await print(bitmap: bitmap, onProgress: { _ in })
    }
}
