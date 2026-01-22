//
//  PrinterSettingsStorage.swift
//  jiji-purinto
//
//  Persistent storage for printer hardware settings.
//

import Foundation
import os

/// Logger for printer settings storage operations.
private let settingsStorageLogger = Logger(subsystem: "com.jiji-purinto", category: "PrinterSettingsStorage")

/// Stores printer settings in UserDefaults.
///
/// Persists quality and energy settings so they can be restored
/// when reconnecting to the printer.
struct PrinterSettingsStorage {
    /// UserDefaults keys for printer settings.
    private enum Keys {
        static let quality = "printerSettings.quality"
        static let energyPercent = "printerSettings.energyPercent"
    }

    /// The UserDefaults instance to use.
    private let defaults: UserDefaults

    /// Creates a PrinterSettingsStorage with the specified UserDefaults.
    ///
    /// - Parameter defaults: The UserDefaults instance to use. Defaults to standard.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Current printer settings.
    ///
    /// Returns default settings if no saved settings exist.
    var settings: PrinterSettings {
        get {
            let quality: PrinterQuality
            let qualitySource: String
            if let qualityRaw = defaults.string(forKey: Keys.quality),
               let savedQuality = PrinterQuality(rawValue: qualityRaw) {
                quality = savedQuality
                qualitySource = "saved"
            } else {
                quality = PrinterSettings.default.quality
                qualitySource = "default"
            }

            let energyPercent: Int
            let energySource: String
            if defaults.object(forKey: Keys.energyPercent) != nil {
                energyPercent = defaults.integer(forKey: Keys.energyPercent)
                energySource = "saved"
            } else {
                energyPercent = PrinterSettings.default.energyPercent
                energySource = "default"
            }

            let loadedSettings = PrinterSettings(quality: quality, energyPercent: energyPercent)
            settingsStorageLogger.info("LOAD settings: quality=\(loadedSettings.quality.rawValue) (\(qualitySource)), energyPercent=\(loadedSettings.energyPercent)% (\(energySource))")

            return loadedSettings
        }
        nonmutating set {
            settingsStorageLogger.info("SAVE settings: quality=\(newValue.quality.rawValue), energyPercent=\(newValue.energyPercent)%")
            defaults.set(newValue.quality.rawValue, forKey: Keys.quality)
            defaults.set(newValue.energyPercent, forKey: Keys.energyPercent)
            settingsStorageLogger.debug("Settings persisted to UserDefaults")
        }
    }

    /// Saves printer settings to persistent storage.
    ///
    /// - Parameter settings: The settings to save.
    func save(_ settings: PrinterSettings) {
        settingsStorageLogger.debug("save() called with quality=\(settings.quality.rawValue), energyPercent=\(settings.energyPercent)%")
        self.settings = settings
    }

    /// Resets settings to defaults.
    func reset() {
        settingsStorageLogger.info("RESET to defaults: quality=\(PrinterSettings.default.quality.rawValue), energyPercent=\(PrinterSettings.default.energyPercent)%")
        defaults.removeObject(forKey: Keys.quality)
        defaults.removeObject(forKey: Keys.energyPercent)
        settingsStorageLogger.debug("Settings keys removed from UserDefaults")
    }
}
