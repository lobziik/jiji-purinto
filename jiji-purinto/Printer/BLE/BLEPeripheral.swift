//
//  BLEPeripheral.swift
//  jiji-purinto
//
//  Wrapper around CBPeripheral providing async/await API for BLE operations.
//

import Foundation
import os
@preconcurrency import CoreBluetooth

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

    /// Writes data to a characteristic.
    ///
    /// - Parameters:
    ///   - data: The data to write.
    ///   - characteristic: The characteristic to write to.
    ///   - type: The write type (withResponse or withoutResponse).
    /// - Throws: `BLEError.writeFailed` if write fails.
    func write(data: Data, to characteristic: CBCharacteristic, type: CBCharacteristicWriteType) async throws(BLEError) {
        if type == .withResponse {
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    writeContinuation.withLock { $0 = continuation }
                    peripheral.writeValue(data, for: characteristic, type: type)
                }
            } catch let error as BLEError {
                throw error
            } catch {
                throw .writeFailed(error)
            }
        } else {
            // Write without response - fire and forget
            peripheral.writeValue(data, for: characteristic, type: type)
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
        if let error = error {
            serviceDiscoveryContinuation.withLock { continuation in
                continuation?.resume(throwing: BLEError.serviceDiscoveryFailed(error))
                continuation = nil
            }
            return
        }

        let services = peripheral.services ?? []

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
        if let error = error {
            characteristicDiscoveryContinuation.withLock { continuation in
                continuation?.resume(throwing: BLEError.characteristicDiscoveryFailed(error))
                continuation = nil
            }
            return
        }

        let characteristics = service.characteristics ?? []

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
        writeContinuation.withLock { continuation in
            if let error = error {
                continuation?.resume(throwing: BLEError.writeFailed(error))
            } else {
                continuation?.resume()
            }
            continuation = nil
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
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
        guard error == nil, let value = characteristic.value else { return }

        notificationContinuations.withLock { continuations in
            _ = continuations[characteristic.uuid]?.yield(value)
        }
    }
}
