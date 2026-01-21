//
//  DebugConfig.swift
//  jiji-purinto
//
//  Centralized debug configuration flags.
//

import Foundation

/// Debug configuration flags.
///
/// Set `enableDebugMenu` to `true` during development to access
/// diagnostic features like test pattern printing.
enum DebugConfig {
    /// Enables the debug menu in Settings.
    ///
    /// Set to `false` for release builds.
    static let enableDebugMenu = true
}

/// Available test patterns for printer diagnostics.
///
/// Each pattern tests a specific aspect of printer functionality
/// and helps diagnose issues like byte order, bit order, or alignment.
enum TestPatternType: String, CaseIterable, Identifiable, Sendable {
    case diagnosticAll = "Full Diagnostic"
    case verticalStripes = "Vertical Stripes"
    case horizontalStripes = "Horizontal Stripes"
    case checkerboard = "Checkerboard"
    case checkerboard5cm = "Checkerboard 5cm"
    case leftBorder = "Left Border"
    case rightBorder = "Right Border"
    case arrow = "Arrow"
    case fullWidthLines = "Full Width Lines"
    case singlePixelTest = "Single Pixel Test"

    var id: String { rawValue }

    /// Description of what this pattern tests.
    var description: String {
        switch self {
        case .diagnosticAll:
            return "All patterns combined"
        case .verticalStripes:
            return "Tests horizontal bit order"
        case .horizontalStripes:
            return "Tests vertical sync"
        case .checkerboard:
            return "Tests bit order (MSB/LSB)"
        case .checkerboard5cm:
            return "Calibration: 2mm cells, 50mm total"
        case .leftBorder:
            return "Tests byte order (should be LEFT)"
        case .rightBorder:
            return "Tests byte order (should be RIGHT)"
        case .arrow:
            return "Tests orientation/mirroring"
        case .fullWidthLines:
            return "Tests full 384px width"
        case .singlePixelTest:
            return "Tests MSB vs LSB positioning"
        }
    }
}
