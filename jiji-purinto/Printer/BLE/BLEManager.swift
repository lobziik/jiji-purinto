//
//  BLEManager.swift
//  jiji-purinto
//
//  Actor wrapping CBCentralManager providing async/await API for BLE operations.
//

import Foundation
import os
@preconcurrency import CoreBluetooth

/// Actor-based wrapper around CBCentralManager for BLE operations.
///
/// Provides a safe, async/await API for scanning, connecting, and managing
/// BLE peripherals. Uses continuations for callback-based CoreBluetooth APIs.
actor BLEManager {

    /// Delegate handler for CBCentralManager callbacks.
    private let delegateHandler: DelegateHandler

    /// The underlying CoreBluetooth central manager.
    private let centralManager: CBCentralManager

    /// Currently connected peripheral wrapper.
    private var connectedPeripheral: BLEPeripheral?

    /// Callback for connection state changes.
    private var onDisconnect: ((UUID, Error?) -> Void)?

    /// Current Bluetooth state.
    var state: CBManagerState {
        centralManager.state
    }

    /// Whether Bluetooth is powered on and ready.
    var isReady: Bool {
        centralManager.state == .poweredOn
    }

    /// Initializes the BLE manager.
    init() {
        self.delegateHandler = DelegateHandler()
        self.centralManager = CBCentralManager(delegate: delegateHandler, queue: nil)
    }

    /// Waits for Bluetooth to be ready.
    ///
    /// - Parameter timeout: Maximum time to wait in seconds.
    /// - Throws: `BLEError` if Bluetooth is unavailable or doesn't become ready.
    func waitForReady(timeout: TimeInterval = 5.0) async throws(BLEError) {
        if centralManager.state == .poweredOn {
            return
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.delegateHandler.waitForPoweredOn()
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw BLEError.timeout
                }

                // Wait for first to complete
                try await group.next()
                group.cancelAll()
            }
        } catch let error as BLEError {
            throw error
        } catch {
            throw .timeout
        }
    }

    /// Scans for peripherals advertising the specified service.
    ///
    /// - Parameters:
    ///   - serviceUUID: The service UUID to scan for.
    ///   - timeout: Scan timeout in seconds.
    /// - Returns: Array of discovered printers.
    /// - Throws: `BLEError` if scan fails.
    func scan(serviceUUID: CBUUID, timeout: TimeInterval = 10.0) async throws(BLEError) -> [DiscoveredPrinter] {
        // Ensure Bluetooth is ready
        try checkBluetoothState()

        // Clear previous scan results
        delegateHandler.clearDiscoveredPeripherals()

        // Start scanning
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        // Wait for timeout
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

        // Stop scanning
        centralManager.stopScan()

        // Get discovered peripherals
        let peripherals = delegateHandler.getDiscoveredPeripherals()

        if peripherals.isEmpty {
            throw .scanTimeout
        }

        return peripherals
    }

    /// Connects to a peripheral.
    ///
    /// - Parameters:
    ///   - peripheralId: The peripheral's identifier.
    ///   - timeout: Connection timeout in seconds.
    /// - Returns: The connected peripheral wrapper.
    /// - Throws: `BLEError` if connection fails.
    func connect(peripheralId: UUID, timeout: TimeInterval = 10.0) async throws(BLEError) -> BLEPeripheral {
        try checkBluetoothState()

        guard let peripheral = delegateHandler.getPeripheral(id: peripheralId) else {
            throw .connectionFailed(nil)
        }

        do {
            try await withThrowingTaskGroup(of: CBPeripheral.self) { group in
                group.addTask {
                    try await self.delegateHandler.waitForConnection(peripheral: peripheral)
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw BLEError.timeout
                }

                // Start connection
                self.centralManager.connect(peripheral, options: nil)

                // Wait for first to complete
                if let connected = try await group.next() {
                    group.cancelAll()
                    let wrapper = BLEPeripheral(peripheral: connected)
                    self.connectedPeripheral = wrapper
                }
            }
        } catch let error as BLEError {
            centralManager.cancelPeripheralConnection(peripheral)
            throw error
        } catch {
            centralManager.cancelPeripheralConnection(peripheral)
            throw .connectionFailed(error)
        }

        guard let wrapper = connectedPeripheral else {
            throw .connectionFailed(nil)
        }

        return wrapper
    }

    /// Disconnects from the currently connected peripheral.
    func disconnect() {
        guard let peripheral = connectedPeripheral?.peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        connectedPeripheral?.didDisconnect()
        connectedPeripheral = nil
    }

    /// Sets the disconnect callback.
    ///
    /// - Parameter callback: Called when a peripheral disconnects unexpectedly.
    func setOnDisconnect(_ callback: @escaping (UUID, Error?) -> Void) {
        self.onDisconnect = callback
        delegateHandler.setOnDisconnect { [weak self] id, error in
            Task { await self?.handleDisconnect(id: id, error: error) }
        }
    }

    /// Handles peripheral disconnection.
    private func handleDisconnect(id: UUID, error: Error?) {
        if connectedPeripheral?.id == id {
            connectedPeripheral?.didDisconnect()
            connectedPeripheral = nil
        }
        onDisconnect?(id, error)
    }

    /// Checks if Bluetooth is in a usable state.
    private func checkBluetoothState() throws(BLEError) {
        switch centralManager.state {
        case .poweredOn:
            return
        case .poweredOff:
            throw .poweredOff
        case .unauthorized:
            throw .unauthorized
        case .unsupported:
            throw .unsupported
        case .unknown, .resetting:
            throw .unavailable
        @unknown default:
            throw .unavailable
        }
    }
}

// MARK: - DelegateHandler

/// Handles CBCentralManagerDelegate callbacks and bridges to async/await.
private final class DelegateHandler: NSObject, CBCentralManagerDelegate, @unchecked Sendable {

    /// Lock for thread-safe access to state.
    private let lock = OSAllocatedUnfairLock<State>(initialState: State())

    /// Internal state protected by lock.
    private struct State {
        var poweredOnContinuation: CheckedContinuation<Void, Error>?
        var connectionContinuation: CheckedContinuation<CBPeripheral, Error>?
        var connectingPeripheral: CBPeripheral?
        var discoveredPeripherals: [UUID: (peripheral: CBPeripheral, rssi: Int)] = [:]
        var onDisconnect: ((UUID, Error?) -> Void)?
    }

    /// Waits for Bluetooth to be powered on.
    func waitForPoweredOn() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { state in
                state.poweredOnContinuation = continuation
            }
        }
    }

    /// Waits for connection to a peripheral.
    func waitForConnection(peripheral: CBPeripheral) async throws -> CBPeripheral {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { state in
                state.connectionContinuation = continuation
                state.connectingPeripheral = peripheral
            }
        }
    }

    /// Clears discovered peripherals before a new scan.
    func clearDiscoveredPeripherals() {
        lock.withLock { state in
            state.discoveredPeripherals.removeAll()
        }
    }

    /// Gets the list of discovered printers.
    func getDiscoveredPeripherals() -> [DiscoveredPrinter] {
        lock.withLock { state in
            state.discoveredPeripherals.values.map { item in
                DiscoveredPrinter(
                    id: item.peripheral.identifier,
                    name: item.peripheral.name,
                    rssi: item.rssi
                )
            }.sorted { $0.rssi > $1.rssi } // Sort by signal strength (higher is better)
        }
    }

    /// Gets a peripheral by ID.
    func getPeripheral(id: UUID) -> CBPeripheral? {
        lock.withLock { state in
            state.discoveredPeripherals[id]?.peripheral
        }
    }

    /// Sets the disconnect callback.
    func setOnDisconnect(_ callback: @escaping (UUID, Error?) -> Void) {
        lock.withLock { state in
            state.onDisconnect = callback
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        lock.withLock { state in
            switch central.state {
            case .poweredOn:
                state.poweredOnContinuation?.resume()
                state.poweredOnContinuation = nil
            case .poweredOff:
                state.poweredOnContinuation?.resume(throwing: BLEError.poweredOff)
                state.poweredOnContinuation = nil
            case .unauthorized:
                state.poweredOnContinuation?.resume(throwing: BLEError.unauthorized)
                state.poweredOnContinuation = nil
            case .unsupported:
                state.poweredOnContinuation?.resume(throwing: BLEError.unsupported)
                state.poweredOnContinuation = nil
            default:
                break
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        lock.withLock { state in
            state.discoveredPeripherals[peripheral.identifier] = (peripheral, RSSI.intValue)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        lock.withLock { state in
            if state.connectingPeripheral?.identifier == peripheral.identifier {
                state.connectionContinuation?.resume(returning: peripheral)
                state.connectionContinuation = nil
                state.connectingPeripheral = nil
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lock.withLock { state in
            if state.connectingPeripheral?.identifier == peripheral.identifier {
                state.connectionContinuation?.resume(throwing: BLEError.connectionFailed(error))
                state.connectionContinuation = nil
                state.connectingPeripheral = nil
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        lock.withLock { state in
            state.onDisconnect?(peripheral.identifier, error)
        }
    }
}
