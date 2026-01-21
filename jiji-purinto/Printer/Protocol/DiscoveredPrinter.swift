//
//  DiscoveredPrinter.swift
//  jiji-purinto
//
//  Represents a printer discovered during BLE scanning.
//

import Foundation

/// A printer discovered during Bluetooth scanning.
///
/// Contains the information needed to identify and connect to a thermal printer.
struct DiscoveredPrinter: Sendable, Identifiable, Equatable {
    /// Unique identifier for this printer (CBPeripheral identifier).
    let id: UUID

    /// The advertised name of the printer, if available.
    let name: String?

    /// Signal strength at discovery time (more negative = weaker signal).
    let rssi: Int

    /// Display name for the UI, using name if available or a fallback.
    var displayName: String {
        name ?? "Unknown Printer (\(id.uuidString.prefix(8)))"
    }
}

extension DiscoveredPrinter: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
