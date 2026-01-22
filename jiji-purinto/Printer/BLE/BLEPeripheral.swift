//
//  BLEPeripheral.swift
//  jiji-purinto
//
//  Wrapper around CBPeripheral providing async/await API for BLE operations.
//

import Foundation
import os
@preconcurrency import CoreBluetooth

/// Logger for BLE peripheral operations.
private let peripheralLogger = Logger(subsystem: "com.jiji-purinto", category: "BLEPeripheral")

/// Wraps a connected CBPeripheral with an async/await API.
///
/// Handles service/characteristic discovery, data writing, and notifications.
/// Uses continuation-based callbacks for async operations.
final class BLEPeripheral: NSObject, @unchecked Sendable {
    /// The underlying CoreBluetooth peripheral.
    let peripheral: CBPeripheral

    /// The peripheral's identifier.
    var id: UUID { peripheral.identifier }

    /// The peripheral's name, if available.
    var name: String? { peripheral.name }

    /// Discovered services keyed by UUID.
    private let discoveredServices = OSAllocatedUnfairLock<[CBUUID: CBService]>(initialState: [:])

    /// Discovered characteristics keyed by UUID.
    private let discoveredCharacteristics = OSAllocatedUnfairLock<[CBUUID: CBCharacteristic]>(initialState: [:])

    /// Continuation for service discovery.
    private let serviceDiscoveryContinuation = OSAllocatedUnfairLock<CheckedContinuation<[CBService], Error>?>(initialState: nil)

    /// Continuation for characteristic discovery.
    private let characteristicDiscoveryContinuation = OSAllocatedUnfairLock<CheckedContinuation<[CBCharacteristic], Error>?>(initialState: nil)

    /// Continuation for write operations.
    private let writeContinuation = OSAllocatedUnfairLock<CheckedContinuation<Void, Error>?>(initialState: nil)

    /// Continuation for notification setup.
    private let notificationContinuation = OSAllocatedUnfairLock<CheckedContinuation<Void, Error>?>(initialState: nil)

    /// Notification stream continuations keyed by characteristic UUID.
    private let notificationContinuations = OSAllocatedUnfairLock<[CBUUID: AsyncStream<Data>.Continuation]>(initialState: [:])

    /// Continuation for write-without-response ready signal.
    ///
    /// Used for flow control when `canSendWriteWithoutResponse` is false.
    private let writeReadyContinuation = OSAllocatedUnfairLock<CheckedContinuation<Void, Never>?>(initialState: nil)

    /// Tracks if peripheralIsReady was signaled while no continuation was waiting.
    ///
    /// This prevents lost signals when the callback fires before `waitForWriteReady()` sets up
    /// its continuation. The signal is consumed on first check.
    private let writeReadySignaled = OSAllocatedUnfairLock<Bool>(initialState: false)

    /// Creates a wrapper around the given peripheral.
    ///
    /// - Parameter peripheral: The connected CBPeripheral to wrap.
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    /// Discovers services on the peripheral.
    ///
    /// - Parameter serviceUUIDs: Optional list of service UUIDs to discover.
    ///   If nil, discovers all services.
    /// - Returns: Array of discovered services.
    /// - Throws: `BLEError` if discovery fails.
    func discoverServices(_ serviceUUIDs: [CBUUID]?) async throws(BLEError) -> [CBService] {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                serviceDiscoveryContinuation.withLock { $0 = continuation }
                peripheral.discoverServices(serviceUUIDs)
            }
        } catch let error as BLEError {
            throw error
        } catch {
            throw .serviceDiscoveryFailed(error)
        }
    }

    /// Discovers characteristics for a service.
    ///
    /// - Parameters:
    ///   - characteristicUUIDs: Optional list of characteristic UUIDs to discover.
    ///   - service: The service to discover characteristics for.
    /// - Returns: Array of discovered characteristics.
    /// - Throws: `BLEError` if discovery fails.
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) async throws(BLEError) -> [CBCharacteristic] {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                characteristicDiscoveryContinuation.withLock { $0 = continuation }
                peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
            }
        } catch let error as BLEError {
            throw error
        } catch {
            throw .characteristicDiscoveryFailed(error)
        }
    }

    /// Gets a discovered service by UUID.
    ///
    /// - Parameter uuid: The service UUID.
    /// - Returns: The service if found.
    /// - Throws: `BLEError.serviceNotFound` if not found.
    func service(for uuid: CBUUID) throws(BLEError) -> CBService {
        guard let service = discoveredServices.withLock({ $0[uuid] }) else {
            throw .serviceNotFound(uuid)
        }
        return service
    }

    /// Gets a discovered characteristic by UUID.
    ///
    /// - Parameter uuid: The characteristic UUID.
    /// - Returns: The characteristic if found.
    /// - Throws: `BLEError.characteristicNotFound` if not found.
    func characteristic(for uuid: CBUUID) throws(BLEError) -> CBCharacteristic {
        guard let characteristic = discoveredCharacteristics.withLock({ $0[uuid] }) else {
            throw .characteristicNotFound(uuid)
        }
        return characteristic
    }

    /// Waits until the peripheral is ready to accept write-without-response data.
    ///
    /// CoreBluetooth's `canSendWriteWithoutResponse` returns `false` when its internal
    /// buffer is full. This method waits for the `peripheralIsReady(toSendWriteWithoutResponse:)`
    /// callback, which fires when buffer space becomes available.
    ///
    /// This implementation handles a race condition where `peripheralIsReady` may fire
    /// before this method sets up its continuation. The signal is stored in `writeReadySignaled`
    /// and consumed on the next call.
    ///
    /// Call this before each write-without-response to implement proper flow control
    /// and prevent silent data loss from buffer overflow.
    private func waitForWriteReady() async {
        // Fast path: if CoreBluetooth says we can send, go ahead
        guard !peripheral.canSendWriteWithoutResponse else {
            peripheralLogger.trace("Write ready immediately (canSend=true)")
            return
        }

        // Check if signal was already received (handles race condition)
        let alreadySignaled = writeReadySignaled.withLock { signaled in
            if signaled {
                signaled = false  // Consume the signal
                return true
            }
            return false
        }

        if alreadySignaled {
            peripheralLogger.trace("Write ready immediately (signal was pending)")
            return
        }

        // Must wait for peripheralIsReady callback
        peripheralLogger.trace("Buffer full, waiting for write ready...")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writeReadyContinuation.withLock { $0 = continuation }

            // Double-check: signal may have arrived between our check and setting continuation
            let signaledNow = writeReadySignaled.withLock { signaled in
                if signaled {
                    signaled = false
                    return true
                }
                return false
            }

            if signaledNow {
                // Signal arrived, resume immediately
                writeReadyContinuation.withLock { cont in
                    cont?.resume()
                    cont = nil
                }
            }
        }
        peripheralLogger.trace("Write ready signal received")
    }

    /// Writes data to a characteristic.
    ///
    /// - Parameters:
    ///   - data: The data to write.
    ///   - characteristic: The characteristic to write to.
    ///   - type: The write type (withResponse or withoutResponse).
    /// - Throws: `BLEError.writeFailed` if write fails.
    func write(data: Data, to characteristic: CBCharacteristic, type: CBCharacteristicWriteType) async throws(BLEError) {
        let typeStr = type == .withResponse ? "withResponse" : "withoutResponse"
        peripheralLogger.trace("Write \(data.count) bytes to \(characteristic.uuid) (\(typeStr))")

        // Check peripheral state
        let state = peripheral.state
        if state != .connected {
            peripheralLogger.error("Write failed: peripheral state is \(state.rawValue) (expected connected=2)")
            throw .notConnected
        }

        // Check characteristic properties
        let props = characteristic.properties
        if type == .withResponse && !props.contains(.write) {
            peripheralLogger.error("Write failed: characteristic doesn't support write with response. Properties: \(props.rawValue)")
        }
        if type == .withoutResponse && !props.contains(.writeWithoutResponse) {
            peripheralLogger.error("Write failed: characteristic doesn't support write without response. Properties: \(props.rawValue)")
        }

        if type == .withResponse {
            do {
                peripheralLogger.trace("Writing with response, waiting for confirmation...")
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    writeContinuation.withLock { $0 = continuation }
                    peripheral.writeValue(data, for: characteristic, type: type)
                }
                peripheralLogger.trace("Write confirmed by peripheral")
            } catch let error as BLEError {
                peripheralLogger.error("Write with response failed: \(error.localizedDescription)")
                throw error
            } catch {
                peripheralLogger.error("Write with response failed: \(error.localizedDescription)")
                throw .writeFailed(error)
            }
        } else {
            // Write without response - use flow control to prevent buffer overflow
            // Wait for buffer space if CoreBluetooth's internal buffer is full
            await waitForWriteReady()

            peripheralLogger.trace("Writing without response")
            peripheral.writeValue(data, for: characteristic, type: type)
            peripheralLogger.trace("Write dispatched to CoreBluetooth")
        }
    }

    /// Enables notifications for a characteristic and returns a stream of values.
    ///
    /// - Parameter characteristic: The characteristic to subscribe to.
    /// - Returns: An async stream of notification data.
    /// - Throws: `BLEError.notificationSetupFailed` if setup fails.
    func notifications(for characteristic: CBCharacteristic) async throws(BLEError) -> AsyncStream<Data> {
        // Enable notifications
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                notificationContinuation.withLock { $0 = continuation }
                peripheral.setNotifyValue(true, for: characteristic)
            }
        } catch let error as BLEError {
            throw error
        } catch {
            throw .notificationSetupFailed(error)
        }

        // Create and store the stream
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        notificationContinuations.withLock { $0[characteristic.uuid] = continuation }

        return stream
    }

    /// Disables notifications for a characteristic.
    ///
    /// - Parameter characteristic: The characteristic to unsubscribe from.
    func disableNotifications(for characteristic: CBCharacteristic) {
        peripheral.setNotifyValue(false, for: characteristic)
        notificationContinuations.withLock { _ = $0.removeValue(forKey: characteristic.uuid) }
    }

    /// Called when the peripheral disconnects to clean up resources.
    func didDisconnect() {
        // Finish all notification streams
        notificationContinuations.withLock { continuations in
            for (_, continuation) in continuations {
                continuation.finish()
            }
            continuations.removeAll()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEPeripheral: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheralLogger.debug("didDiscoverServices called (error: \(error?.localizedDescription ?? "none"))")
        if let error = error {
            serviceDiscoveryContinuation.withLock { continuation in
                continuation?.resume(throwing: BLEError.serviceDiscoveryFailed(error))
                continuation = nil
            }
            return
        }

        let services = peripheral.services ?? []
        peripheralLogger.debug("Discovered \(services.count) services: \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")

        // Cache discovered services
        discoveredServices.withLock { cache in
            for service in services {
                cache[service.uuid] = service
            }
        }

        serviceDiscoveryContinuation.withLock { continuation in
            continuation?.resume(returning: services)
            continuation = nil
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        peripheralLogger.debug("didDiscoverCharacteristics for \(service.uuid) (error: \(error?.localizedDescription ?? "none"))")
        if let error = error {
            characteristicDiscoveryContinuation.withLock { continuation in
                continuation?.resume(throwing: BLEError.characteristicDiscoveryFailed(error))
                continuation = nil
            }
            return
        }

        let characteristics = service.characteristics ?? []
        for char in characteristics {
            peripheralLogger.debug("  Characteristic: \(char.uuid) properties: \(char.properties.rawValue)")
        }

        // Cache discovered characteristics
        discoveredCharacteristics.withLock { cache in
            for characteristic in characteristics {
                cache[characteristic.uuid] = characteristic
            }
        }

        characteristicDiscoveryContinuation.withLock { continuation in
            continuation?.resume(returning: characteristics)
            continuation = nil
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        peripheralLogger.debug("didWriteValue for \(characteristic.uuid) (error: \(error?.localizedDescription ?? "none"))")
        writeContinuation.withLock { continuation in
            if let error = error {
                peripheralLogger.error("Write callback error: \(error.localizedDescription)")
                continuation?.resume(throwing: BLEError.writeFailed(error))
            } else {
                peripheralLogger.trace("Write callback success")
                continuation?.resume()
            }
            continuation = nil
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        peripheralLogger.debug("didUpdateNotificationState for \(characteristic.uuid) (error: \(error?.localizedDescription ?? "none"))")
        notificationContinuation.withLock { continuation in
            if let error = error {
                continuation?.resume(throwing: BLEError.notificationSetupFailed(error))
            } else {
                continuation?.resume()
            }
            continuation = nil
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            peripheralLogger.error("didUpdateValue error for \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        guard let value = characteristic.value else {
            peripheralLogger.warning("didUpdateValue for \(characteristic.uuid): no value")
            return
        }

        peripheralLogger.debug("didUpdateValue for \(characteristic.uuid): \(value.count) bytes - \(value.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " "))")

        notificationContinuations.withLock { continuations in
            _ = continuations[characteristic.uuid]?.yield(value)
        }
    }

    /// Called when the peripheral is ready to accept more write-without-response data.
    ///
    /// This callback fires when CoreBluetooth's internal buffer has space after
    /// `canSendWriteWithoutResponse` was `false`. If a continuation is waiting,
    /// it is resumed immediately. Otherwise, the signal is stored in `writeReadySignaled`
    /// for the next `waitForWriteReady()` call to consume.
    nonisolated func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        peripheralLogger.trace("peripheralIsReady called - buffer has space")

        // Try to resume waiting continuation
        var resumed = false
        writeReadyContinuation.withLock { continuation in
            if let cont = continuation {
                cont.resume()
                continuation = nil
                resumed = true
            }
        }

        // If no one was waiting, store the signal for later
        if !resumed {
            writeReadySignaled.withLock { $0 = true }
            peripheralLogger.trace("peripheralIsReady: no waiter, signal stored")
        }
    }
}
