# Jiji-Purinto Milestones

Progress tracking for all development milestones.

## v0.1 — Skeleton ✅

- [x] Xcode project setup
- [x] FSM module with tests
  - [x] `AppState` - 7 states (idle, selecting, processing, preview, printing, done, error)
  - [x] `AppEvent` - all transition events
  - [x] `AppFSM` - pure transition function
  - [x] `FSMError` - invalidTransition, guardFailed
  - [x] `FSMContext` - guard conditions (printerReady)
  - [x] Unit tests (40 tests passing)
- [x] Basic navigation (Home → Preview)
  - [x] State-driven view switching in ContentView
  - [x] AppCoordinator connecting FSM to SwiftUI
- [x] Placeholder UI
  - [x] HomeScreen with camera/gallery buttons
  - [x] ProcessingScreen with spinner
  - [x] PreviewScreen with image + print button
  - [x] PrintingScreen with progress
  - [x] DoneScreen
  - [x] ErrorScreen
  - [x] BigButton component

## v0.2 — Image Processing ✅

- [x] ImageProcessor module
  - [x] `ImageProcessor.swift` - public API (actor-based)
  - [x] `MonoBitmap.swift` - 1-bit packed bitmap type
  - [x] `ProcessingError.swift` - error types
- [x] Pipeline stages
  - [x] `ImageNormalizer.swift` - CGImage normalization
  - [x] `ImageResizer.swift` - Resize to 384px width (Lanczos via vImage)
  - [x] `GrayscaleConverter.swift` - Grayscale conversion (vImage)
  - [x] `BrightnessContrast.swift` - Brightness/contrast adjustment
- [x] Dither algorithms
  - [x] `ThresholdDither.swift` - Simple threshold
  - [x] `FloydSteinbergDither.swift` - Error diffusion
  - [x] `AtkinsonDither.swift` - Atkinson error diffusion
  - [x] `OrderedDither.swift` - Bayer matrix
  - [x] `DitherAlgorithmProtocol.swift` - Protocol + factory
- [x] Settings + live preview
  - [x] `SettingsSheet.swift` - brightness, contrast, algorithm
  - [x] Real-time preview updates
  - [x] `ImageSettings.swift` - settings type with defaults
- [x] Unit tests for algorithms (24+ tests)
- [x] Image picker integration
  - [x] `ImagePickerView.swift` - Camera/gallery picker
  - [x] `PhotoLibraryPermission.swift` - Permissions handling

## v0.3 — Printer ✅

- [x] BLE Manager
  - [x] `BLEManager.swift` - Actor wrapping CBCentralManager
  - [x] `BLEPeripheral.swift` - Peripheral wrapper with async/await API
  - [x] `BLEError.swift` - BLE-specific errors
- [x] Printer protocol
  - [x] `ThermalPrinter.swift` - Protocol definition
  - [x] `PrinterStatus.swift` - Simplified status for UI
  - [x] `PrinterError.swift` - Printer-specific errors
  - [x] `DiscoveredPrinter.swift` - Scan result type
- [x] Cat/MX driver
  - [x] `CatMXPrinter.swift` - ThermalPrinter implementation
  - [x] `CatMXCommands.swift` - Command builders with CRC
  - [x] `CatMXConstants.swift` - UUIDs (0xAE30/0xAE01/0xAE02), MTU, packet format
- [x] PrinterFSM
  - [x] `PrinterState.swift` - 6 states: disconnected, scanning, connecting, ready, busy, error
  - [x] `PrinterEvent.swift` - Events and transitions
  - [x] `PrinterFSM.swift` - Pure transition function
  - [x] Unit tests (37 tests: 17 valid + 20 invalid transitions)
- [x] Connect/disconnect flow
  - [x] Scan for printers
  - [x] Connect to selected printer
  - [x] `PrinterStorage.swift` - Save last printer to UserDefaults
- [x] Print flow
  - [x] Send bitmap data (chunked by MTU)
  - [x] Progress reporting
  - [x] Error handling
- [x] Status indicator
  - [x] `PrinterStatusView.swift` - Visual indicator with animated dot
  - [x] `PrinterScanSheet.swift` - Tap to scan/connect
- [x] Integration
  - [x] `PrinterCoordinator.swift` - Connects PrinterFSM to app
  - [x] AppCoordinator integration with printerCoordinator
  - [x] Info.plist Bluetooth permissions
- [x] Command tests (17 tests for CatMX protocol)

## v0.4 — Polish

- [ ] Error handling UI
  - [ ] User-friendly error messages
  - [ ] Retry actions
  - [ ] Recovery suggestions
- [ ] Auto-reconnect
  - [x] Attempt reconnect on app launch (implemented in PrinterCoordinator)
  - [ ] Silent reconnect (no error if fails)
  - [ ] Reconnect on connection lost
- [ ] Localization (EN/RU)
  - [ ] String catalog setup
  - [ ] English strings
  - [ ] Russian strings
- [ ] App icon
  - [ ] Design app icon
  - [ ] All required sizes

## v1.0 — Release

- [ ] All tests passing
- [ ] Test on real device + printer
- [ ] Performance optimization
- [ ] Memory usage audit
- [ ] Build & distribute via Ad-hoc
  - [ ] Provisioning profile
  - [ ] Export IPA
  - [ ] Installation instructions
