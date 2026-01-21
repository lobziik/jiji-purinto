# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Jiji-Purinto (ジジプリント)** - Native iOS app for printing photos on a BLE thermal printer, designed for toddler-friendly interface.

- **Language**: Swift 5.9+ (strict concurrency, Swift 6 ready)
- **UI Framework**: SwiftUI
- **Minimum iOS**: 16.0
- **Architecture**: FSM (Finite State Machine) + MVVM
- **Dependencies**: Zero external (system frameworks only: SwiftUI, CoreBluetooth, CoreImage, Accelerate)
- **Target Printer**: Cat/MX family (MX05-MX11, GB01-03), BLE GATT, Service UUID `0xAE30`, 384px print width

## Build Commands

```bash
# Build
xcodebuild build -scheme jiji-purinto -project jiji-purinto/jiji-purinto.xcodeproj

# Run tests (unit + UI)
xcodebuild test -scheme jiji-purinto -project jiji-purinto/jiji-purinto.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 16'

# Run only unit tests
xcodebuild test -scheme jiji-purinto -project jiji-purinto/jiji-purinto.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:jiji-purintoTests

# Archive for distribution
xcodebuild archive -scheme jiji-purinto -project jiji-purinto/jiji-purinto.xcodeproj -archivePath build/JijiPurinto.xcarchive
```

## Architecture

### FSM + MVVM Pattern

Two state machines manage the application:

**AppFSM** - Application flow:
```
idle → selecting(.camera|.gallery) → processing → preview → printing → done
                                                                    ↘ error
```

**PrinterFSM** - Printer connection lifecycle:
```
disconnected → scanning → connecting → ready → busy
                                         ↘ error
```

All state transitions must be explicitly defined. Invalid transitions throw `FSMError.invalidTransition`.

### Project Structure

```
jiji-purinto/jiji-purinto/
├── App/
│   ├── AppCoordinator.swift         # Connects AppFSM to SwiftUI
│   └── PrinterCoordinator.swift     # Connects PrinterFSM to app
├── Core/
│   ├── FSM/
│   │   ├── AppState.swift           # 7 states: idle, selecting, processing, preview, printing, done, error
│   │   ├── AppEvent.swift           # App transition events
│   │   ├── AppFSM.swift             # Pure transition function
│   │   ├── FSMContext.swift         # Guard condition context
│   │   ├── FSMError.swift           # invalidTransition, guardFailed
│   │   ├── PrinterState.swift       # 6 states: disconnected, scanning, connecting, ready, busy, error
│   │   ├── PrinterEvent.swift       # Printer transition events
│   │   └── PrinterFSM.swift         # Printer state machine
│   ├── Storage/
│   │   └── PrinterStorage.swift     # UserDefaults persistence for last printer
│   └── Types/
│       ├── ImageSource.swift        # camera, gallery
│       ├── ImageSettings.swift      # brightness, contrast, dither algorithm
│       └── AppError.swift           # Application errors
├── Features/
│   ├── ImageProcessing/
│   │   ├── ImageProcessor.swift     # Actor-based processing pipeline
│   │   ├── Types/
│   │   │   ├── MonoBitmap.swift     # 1-bit packed bitmap
│   │   │   └── ProcessingError.swift
│   │   ├── Pipeline/
│   │   │   ├── ImageNormalizer.swift
│   │   │   ├── ImageResizer.swift
│   │   │   ├── GrayscaleConverter.swift
│   │   │   └── BrightnessContrast.swift
│   │   └── Algorithms/
│   │       ├── DitherAlgorithmProtocol.swift
│   │       ├── ThresholdDither.swift
│   │       ├── FloydSteinbergDither.swift
│   │       ├── AtkinsonDither.swift
│   │       └── OrderedDither.swift
│   └── ImagePicker/
│       ├── ImagePickerView.swift
│       └── PhotoLibraryPermission.swift
├── Printer/
│   ├── Protocol/
│   │   ├── ThermalPrinter.swift     # Printer driver protocol
│   │   ├── PrinterError.swift       # Printer-specific errors
│   │   ├── PrinterStatus.swift      # Simplified status for UI
│   │   └── DiscoveredPrinter.swift  # Scan result type
│   ├── BLE/
│   │   ├── BLEManager.swift         # Actor wrapping CBCentralManager
│   │   ├── BLEPeripheral.swift      # Peripheral wrapper with async/await
│   │   └── BLEError.swift           # BLE-specific errors
│   └── Drivers/CatMX/
│       ├── CatMXPrinter.swift       # ThermalPrinter implementation
│       ├── CatMXCommands.swift      # Command builders with CRC
│       └── CatMXConstants.swift     # UUIDs, MTU, protocol constants
├── UI/
│   ├── Screens/
│   │   ├── HomeScreen.swift         # Camera + gallery buttons + printer status
│   │   ├── ProcessingScreen.swift
│   │   ├── PreviewScreen.swift      # Image preview + print button + settings
│   │   └── SettingsSheet.swift      # Brightness, contrast, algorithm
│   └── Components/
│       ├── BigButton.swift          # Toddler-friendly buttons
│       └── PrinterStatusView.swift  # Status indicator + scan sheet
├── ContentView.swift                # State-driven view switching
└── jiji_purintoApp.swift            # App entry point

jiji-purintoTests/
├── FSM/
│   ├── AppFSMTransitionTests.swift  # Valid transitions
│   ├── AppFSMInvalidTests.swift     # Invalid transitions
│   └── AppFSMGuardTests.swift       # Guard conditions
├── ImageProcessing/
│   ├── ImageProcessorTests.swift
│   ├── DitherAlgorithmTests.swift
│   └── MonoBitmapTests.swift
└── Printer/
    ├── PrinterFSMTests.swift        # Valid transitions
    ├── PrinterFSMInvalidTests.swift # Invalid transitions
    └── CatMXCommandsTests.swift     # Command byte verification
```

### Image Processing Pipeline

```
UIImage → CGImage (normalized) → Resize 384px → Grayscale → Brightness/Contrast → Dither → MonoBitmap (1-bit packed)
```

Dither algorithms: `threshold`, `floydSteinberg`, `atkinson`, `ordered`

### Cat/MX Printer Protocol

Command format: `[0x51, 0x78] [cmd] [00] [length_low] [length_high] [data...] [crc] [0xFF]`

Key UUIDs:
- Service: `0xAE30`
- Notify characteristic: `0xAE01`
- Write characteristic: `0xAE02`

## Code Conventions

### Error Handling - FAIL FAST AND LOUD

```swift
// ✅ Correct - fail explicitly
func process() async throws(ProcessingError) {
    let data: Data
    do {
        data = try await loadData()
    } catch let error as LoadError {
        throw .invalidImage
    } catch {
        throw .unexpected(error)
    }
}

// ❌ Wrong - silent failure
func process() throws {
    let data = try? loadData()  // Never do this
}
```

### Type Safety

- **Never use `Any`** - all types must be explicit
- **No force unwrap** - use `guard let` or `if let`
- **Typed throws** (Swift 6) where possible
- **Result type** for sync operations, **async throws** for async

### FSM Test Pattern (Swift Testing)

```swift
import Foundation
import Testing
@testable import jiji_purinto

@Suite("PrinterFSM Transitions")
struct PrinterFSMTests {
    let fsm = PrinterFSM()

    // Test valid transition
    @Test("disconnected + startScan -> scanning")
    func disconnected_startScan_transitionsToScanning() throws {
        let next = try fsm.transition(from: .disconnected, event: .startScan)
        #expect(next == .scanning)
    }

    // Test invalid transition
    @Test("disconnected + printStart throws")
    func disconnected_printStart_throws() {
        #expect(throws: FSMError.self) {
            _ = try fsm.transition(from: .disconnected, event: .printStart)
        }
    }
}
```

## Reference Documentation

- `MILESTONES.md` - Progress checklist for all milestones (v0.1 through v1.0)
- `jiji-purinto-ios-outline.md` - Comprehensive project specification including:
  - FSM state/event definitions with transition tables
  - Image processing pipeline and algorithm specs
  - Cat/MX printer protocol details and command formats
  - UI screen layouts and flows

## Distribution

Ad-hoc distribution via:
- AltStore (7-day refresh)
- Sideloadly
- Apple Configurator
