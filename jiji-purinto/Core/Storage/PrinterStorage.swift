//
//  PrinterStorage.swift
//  jiji-purinto
//
//  Persistent storage for printer connection preferences.
//

import Foundation

/// Stores printer preferences in UserDefaults.
///
/// Persists the last connected printer information for auto-reconnect functionality.
struct PrinterStorage {
    /// UserDefaults keys for printer storage.
    private enum Keys {
        static let lastPrinterId = "printer.lastId"
        static let lastPrinterName = "printer.lastName"
    }

    /// The UserDefaults instance to use.
    private let defaults: UserDefaults

    /// Creates a PrinterStorage with the specified UserDefaults.
    ///
    /// - Parameter defaults: The UserDefaults instance to use. Defaults to standard.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The last connected printer's ID.
    var lastPrinterId: UUID? {
        get {
            guard let uuidString = defaults.string(forKey: Keys.lastPrinterId) else {
                return nil
            }
            return UUID(uuidString: uuidString)
        }
        nonmutating set {
            if let value = newValue {
                defaults.set(value.uuidString, forKey: Keys.lastPrinterId)
            } else {
                defaults.removeObject(forKey: Keys.lastPrinterId)
            }
        }
    }

    /// The last connected printer's name.
    var lastPrinterName: String? {
        get {
            defaults.string(forKey: Keys.lastPrinterName)
        }
        nonmutating set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.lastPrinterName)
            } else {
                defaults.removeObject(forKey: Keys.lastPrinterName)
            }
        }
    }

    /// Saves the last connected printer information.
    ///
    /// - Parameters:
    ///   - id: The printer's UUID.
    ///   - name: The printer's display name.
    func saveLastPrinter(id: UUID, name: String) {
        lastPrinterId = id
        lastPrinterName = name
    }

    /// Clears the stored printer information.
    func clearLastPrinter() {
        lastPrinterId = nil
        lastPrinterName = nil
    }

    /// Whether there is a saved printer to reconnect to.
    var hasSavedPrinter: Bool {
        lastPrinterId != nil
    }
}
