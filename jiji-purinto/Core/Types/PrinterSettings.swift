//
//  PrinterSettings.swift
//  jiji-purinto
//
//  Printer hardware settings for Cat/MX thermal printers.
//

import Foundation

/// Print quality levels matching CatMXConstants.Quality.
///
/// These levels control the print density/darkness and affect print speed.
enum PrinterQuality: String, CaseIterable, Sendable {
    /// Light print (faster, uses less energy).
    case light

    /// Normal print quality (default).
    case normal

    /// Dark print (slower, uses more energy).
    case dark

    /// Human-readable display name for UI.
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .normal:
            return "Normal"
        case .dark:
            return "Dark"
        }
    }

    /// Converts to the corresponding CatMXConstants.Quality value.
    var catMXQuality: CatMXConstants.Quality {
        switch self {
        case .light:
            return .light
        case .normal:
            return .normal
        case .dark:
            return .dark
        }
    }
}

/// Printer hardware settings for Cat/MX printers.
///
/// These settings control physical printer behavior like print density
/// and heat level. Settings persist between app sessions and are applied
/// automatically on reconnect.
struct PrinterSettings: Equatable, Sendable {
    /// Print quality/density level.
    var quality: PrinterQuality

    /// Energy level as percentage (0-100).
    ///
    /// Maps to 0x00-0xFF internally. Higher values produce darker prints
    /// but use more battery and may cause overheating on long prints.
    /// Default is 37% (0x60).
    var energyPercent: Int

    /// Default settings (normal quality, 37% energy = 0x60).
    static let `default` = PrinterSettings(quality: .normal, energyPercent: 37)

    /// Converts energy percentage to the byte value expected by the printer.
    ///
    /// - Returns: Energy level as UInt8 (0x00-0xFF).
    var energyByte: UInt8 {
        UInt8(clamping: energyPercent * 255 / 100)
    }
}
