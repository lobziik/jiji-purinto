//
//  BLEError.swift
//  jiji-purinto
//
//  BLE-specific error types for low-level Bluetooth operations.
//

import Foundation
@preconcurrency import CoreBluetooth

/// Errors that can occur during low-level BLE operations.
///
/// These errors are internal to the BLE layer and are typically
/// mapped to PrinterError for the higher-level printer API.
enum BLEError: Error, Sendable {
    /// Bluetooth is not available on this device.
    case unavailable

    /// Bluetooth is powered off.
    case poweredOff

    /// Bluetooth permission was denied.
    case unauthorized

    /// Bluetooth is in an unsupported state.
    case unsupported

    /// Scan timed out without finding devices.
    case scanTimeout

    /// Connection to peripheral failed.
    case connectionFailed(Error?)

    /// Connection to peripheral was cancelled.
    case connectionCancelled

    /// Peripheral disconnected unexpectedly.
    case disconnected(Error?)

    /// Service discovery failed.
    case serviceDiscoveryFailed(Error?)

    /// Required service was not found.
    case serviceNotFound(CBUUID)

    /// Characteristic discovery failed.
    case characteristicDiscoveryFailed(Error?)

    /// Required characteristic was not found.
    case characteristicNotFound(CBUUID)

    /// Failed to write to characteristic.
    case writeFailed(Error?)

    /// Failed to enable notifications.
    case notificationSetupFailed(Error?)

    /// Operation timed out.
    case timeout

    /// Peripheral is not connected.
    case notConnected

    /// Device not found (not in cache and not known to system).
    case deviceNotFound

    /// Converts this BLE error to a PrinterError for the higher-level API.
    var asPrinterError: PrinterError {
        switch self {
        case .unavailable:
            return .bluetoothUnavailable
        case .poweredOff:
            return .bluetoothPoweredOff
        case .unauthorized:
            return .bluetoothUnauthorized
        case .unsupported:
            return .bluetoothUnavailable
        case .scanTimeout:
            return .scanTimeout
        case .connectionFailed(let error):
            return .connectionFailed(reason: error?.localizedDescription ?? "Unknown error")
        case .connectionCancelled:
            return .connectionFailed(reason: "Connection cancelled")
        case .disconnected:
            return .connectionLost
        case .serviceDiscoveryFailed(let error):
            return .connectionFailed(reason: error?.localizedDescription ?? "Service discovery failed")
        case .serviceNotFound:
            return .serviceNotFound
        case .characteristicDiscoveryFailed(let error):
            return .connectionFailed(reason: error?.localizedDescription ?? "Characteristic discovery failed")
        case .characteristicNotFound:
            return .characteristicNotFound
        case .writeFailed(let error):
            return .writeFailed(reason: error?.localizedDescription ?? "Unknown error")
        case .notificationSetupFailed(let error):
            return .connectionFailed(reason: error?.localizedDescription ?? "Notification setup failed")
        case .timeout:
            return .connectionFailed(reason: "Operation timed out")
        case .notConnected:
            return .connectionLost
        case .deviceNotFound:
            return .connectionFailed(reason: "Device not found - please scan again")
        }
    }
}

extension BLEError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Bluetooth is not available"
        case .poweredOff:
            return "Bluetooth is powered off"
        case .unauthorized:
            return "Bluetooth permission denied"
        case .unsupported:
            return "Bluetooth is not supported"
        case .scanTimeout:
            return "Scan timed out"
        case .connectionFailed(let error):
            return "Connection failed: \(error?.localizedDescription ?? "Unknown")"
        case .connectionCancelled:
            return "Connection was cancelled"
        case .disconnected(let error):
            return "Disconnected: \(error?.localizedDescription ?? "Unknown")"
        case .serviceDiscoveryFailed(let error):
            return "Service discovery failed: \(error?.localizedDescription ?? "Unknown")"
        case .serviceNotFound(let uuid):
            return "Service \(uuid) not found"
        case .characteristicDiscoveryFailed(let error):
            return "Characteristic discovery failed: \(error?.localizedDescription ?? "Unknown")"
        case .characteristicNotFound(let uuid):
            return "Characteristic \(uuid) not found"
        case .writeFailed(let error):
            return "Write failed: \(error?.localizedDescription ?? "Unknown")"
        case .notificationSetupFailed(let error):
            return "Notification setup failed: \(error?.localizedDescription ?? "Unknown")"
        case .timeout:
            return "Operation timed out"
        case .notConnected:
            return "Not connected"
        case .deviceNotFound:
            return "Device not found"
        }
    }
}
