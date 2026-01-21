# Jiji-Purinto iOS (ジジプリント)

Нативное iOS приложение для печати фото на BLE термопринтере.
Интерфейс для двухлетнего ребёнка.

## Стек

- **UI**: SwiftUI
- **Minimum iOS**: 15.0
- **Language**: Swift 5.9+ (strict concurrency)
- **BLE**: CoreBluetooth
- **Architecture**: FSM + MVVM
- **Distribution**: Ad-hoc (Provisioning Profile)

## Целевой принтер

- **Семейство**: Cat/MX (MX05-MX11, GB01-03)
- **Протокол**: BLE GATT
- **Service UUID**: `0xAE30`
- **Ширина печати**: 384px

---

## Структура проекта

```
JijiPurinto/
├── App/
│   ├── JijiPurintoApp.swift
│   └── AppState.swift
│
├── Features/
│   ├── ImagePicker/
│   │   ├── ImagePickerView.swift
│   │   └── PhotoLibraryPermission.swift
│   │
│   ├── ImageProcessing/          # Standalone module
│   │   ├── ImageProcessor.swift
│   │   ├── Pipeline/
│   │   │   ├── Resize.swift
│   │   │   ├── Grayscale.swift
│   │   │   ├── Brightness.swift
│   │   │   ├── Contrast.swift
│   │   │   └── Dither.swift
│   │   ├── Algorithms/
│   │   │   ├── ThresholdDither.swift
│   │   │   ├── FloydSteinbergDither.swift
│   │   │   ├── AtkinsonDither.swift
│   │   │   └── OrderedDither.swift
│   │   ├── Types/
│   │   │   ├── MonoBitmap.swift
│   │   │   ├── ImageSettings.swift
│   │   │   └── ProcessingError.swift
│   │   └── index.swift           # Public API
│   │
│   ├── Preview/
│   │   ├── PreviewScreen.swift
│   │   ├── PreviewViewModel.swift
│   │   └── SettingsSheet.swift       # Sheet с настройками (⚙️)
│   │
│   └── Printing/
│       ├── PrintingScreen.swift
│       └── PrintingViewModel.swift
│
├── Printer/                      # Abstracted printer module
│   ├── Protocol/
│   │   ├── ThermalPrinter.swift
│   │   ├── PrinterStatus.swift
│   │   └── PrinterError.swift
│   │
│   ├── BLE/
│   │   ├── BLEManager.swift
│   │   ├── BLEPeripheral.swift
│   │   └── BLEError.swift
│   │
│   └── Drivers/
│       └── CatMX/
│           ├── CatMXPrinter.swift
│           ├── CatMXCommands.swift
│           └── CatMXConstants.swift
│
├── Core/
│   ├── FSM/
│   │   ├── AppFSM.swift
│   │   ├── PrinterFSM.swift
│   │   ├── FSMTransition.swift
│   │   └── FSMError.swift
│   │
│   ├── Storage/
│   │   └── PrinterStorage.swift
│   │
│   └── Errors/
│       ├── JijiError.swift
│       └── ErrorRecovery.swift
│
├── UI/
│   ├── Screens/
│   │   ├── HomeScreen.swift
│   │   └── ErrorScreen.swift
│   │
│   └── Components/
│       ├── BigButton.swift
│       ├── StatusIndicator.swift
│       └── ProgressRing.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.xcstrings     # String Catalog (Xcode 15+)
    └── Info.plist
```

---

## ImageProcessing Module

### Public API

```swift
// Единственная точка входа
public struct ImageProcessor {
    public static func process(
        image: UIImage,
        settings: ImageSettings
    ) async throws -> MonoBitmap
    
    public static func preview(
        image: UIImage,
        settings: ImageSettings,
        targetSize: CGSize
    ) async throws -> UIImage
}
```

### Types

```swift
public struct ImageSettings: Equatable, Sendable {
    public var brightness: Float    // -1.0 ... +1.0, default 0
    public var contrast: Float      // 0.5 ... 2.0, default 1.0
    public var algorithm: DitherAlgorithm
    
    // Разумные дефолты — работают для большинства фото
    public static let `default` = ImageSettings(
        brightness: 0.05,              // Чуть светлее (термопечать темнит)
        contrast: 1.1,                 // Чуть контрастнее
        algorithm: .floydSteinberg     // Лучший для фото
    )
}

public enum DitherAlgorithm: String, CaseIterable, Sendable {
    case threshold          // Простой порог
    case floydSteinberg     // Для фото
    case atkinson           // Винтаж
    case ordered            // Паттерн
}

public struct MonoBitmap: Sendable {
    public let width: Int           // Always 384
    public let height: Int          // Variable
    public let data: Data           // Packed bits (1 bit per pixel)
    
    public var bytesPerRow: Int { (width + 7) / 8 }
}
```

### Processing Pipeline

```
UIImage
    │
    ├─→ Validate (non-empty, decodable)
    │
    ▼
CGImage (normalized orientation)
    │
    ├─→ Resize to 384px width (Lanczos)
    │
    ▼
Grayscale buffer (vImage)
    │
    ├─→ Brightness adjustment
    ├─→ Contrast adjustment
    │
    ▼
Float buffer [0...1]
    │
    ├─→ Dither algorithm
    │
    ▼
MonoBitmap (1-bit packed)
```

### Algorithm Details

| Algorithm | Speed | Quality | Best for |
|-----------|-------|---------|----------|
| `threshold` | ⚡⚡⚡ | ⭐ | Текст, штриховка |
| `floydSteinberg` | ⚡⚡ | ⭐⭐⭐ | Фото, градиенты |
| `atkinson` | ⚡⚡ | ⭐⭐ | Винтаж, меньше чернил |
| `ordered` | ⚡⚡⚡ | ⭐⭐ | Паттерны, ретро |

### Error Types

```swift
public enum ProcessingError: Error {
    case invalidImage
    case resizeFailed
    case ditherFailed(underlying: Error)
}
```

---

## Printer Protocol Abstraction

### Protocol Definition

```swift
public protocol ThermalPrinter: AnyObject, Sendable {
    var status: PrinterStatus { get }
    var statusStream: AsyncStream<PrinterStatus> { get }
    
    func scan() async throws -> [DiscoveredPrinter]
    func connect(to printer: DiscoveredPrinter) async throws
    func connectToLast() async throws -> Bool
    func disconnect()
    
    func print(
        bitmap: MonoBitmap,
        onProgress: @escaping @Sendable (Float) -> Void
    ) async throws
}

public struct DiscoveredPrinter: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let rssi: Int
}
```

### Status

```swift
public enum PrinterStatus: Equatable, Sendable {
    case disconnected
    case scanning
    case connecting
    case ready(deviceName: String)
    case printing(progress: Float)
    case error(PrinterError)
    
    public var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}
```

### Errors

```swift
public enum PrinterError: Error, Equatable {
    case bluetoothOff
    case bluetoothUnauthorized
    case notFound
    case connectionFailed(String)
    case connectionLost
    case printFailed(String)
    case busy
}
```

---

## Cat/MX Driver Implementation

### Constants

```swift
enum CatMXConstants {
    static let serviceUUID = CBUUID(string: "AE30")
    static let notifyCharUUID = CBUUID(string: "AE01")
    static let writeCharUUID = CBUUID(string: "AE02")
    
    static let printWidth = 384
    static let defaultMTU = 20
    static let commandPrefix: [UInt8] = [0x51, 0x78]
}
```

### Commands

```swift
enum CatMXCommands {
    // Set print quality (0x00 = normal, 0x01 = high)
    static func setQuality(_ quality: UInt8) -> Data
    
    // Feed paper (lines)
    static func feedPaper(_ lines: UInt8) -> Data
    
    // Print bitmap line (48 bytes = 384 bits)
    static func printLine(_ data: Data) -> Data
    
    // Get device status
    static func getStatus() -> Data
    
    // Set energy (density)
    static func setEnergy(_ level: UInt8) -> Data
}
```

### Packet Format

```
┌──────────┬──────────┬──────────┬─────────────┐
│ 0x51     │ 0x78     │ Command  │ Payload...  │
│ (prefix) │ (prefix) │ (1 byte) │ (variable)  │
└──────────┴──────────┴──────────┴─────────────┘
```

---

## FSM: App State Machine

### States

```swift
enum AppState: Equatable {
    case idle
    case selecting(source: ImageSource)
    case processing
    case preview(image: UIImage, settings: ImageSettings)
    case printing(progress: Float)
    case done
    case error(AppError)
}

enum ImageSource {
    case camera
    case gallery
}
```

### Events

```swift
enum AppEvent {
    case openCamera
    case openGallery
    case cancelSelection
    case imageSelected(UIImage)
    case imageSelectionFailed(Error)
    case processingComplete(UIImage)
    case processingFailed(Error)
    case settingsChanged(ImageSettings)
    case print
    case printProgress(Float)
    case printSuccess
    case printFailed(Error)
    case reset
}
```

### Transitions

| From | Event | To | Guard |
|------|-------|-----|-------|
| `idle` | `openCamera` | `selecting(.camera)` | — |
| `idle` | `openGallery` | `selecting(.gallery)` | — |
| `selecting` | `imageSelected` | `processing` | — |
| `selecting` | `imageSelectionFailed` | `error` | — |
| `selecting` | `cancelSelection` | `idle` | — |
| `processing` | `processingComplete` | `preview` | — |
| `processing` | `processingFailed` | `error` | — |
| `preview` | `settingsChanged` | `preview` | — |
| `preview` | `print` | `printing` | `printerReady` |
| `preview` | `openCamera` | `selecting(.camera)` | — |
| `preview` | `openGallery` | `selecting(.gallery)` | — |
| `printing` | `printProgress` | `printing` | — |
| `printing` | `printSuccess` | `done` | — |
| `printing` | `printFailed` | `error` | — |
| `done` | `reset` | `idle` | — |
| `done` | `openCamera` | `selecting(.camera)` | — |
| `done` | `openGallery` | `selecting(.gallery)` | — |
| `error` | `reset` | `idle` | — |

### Invalid Transitions

Любой переход не из таблицы → `FSMError.invalidTransition`

---

## FSM: Printer State Machine

### States

```swift
enum PrinterState: Equatable {
    case disconnected
    case scanning
    case connecting
    case ready(deviceId: UUID, deviceName: String)
    case busy(deviceId: UUID)
    case error(PrinterError)
}
```

### Events

```swift
enum PrinterEvent {
    case scan
    case scanComplete([DiscoveredPrinter])
    case scanFailed(PrinterError)
    case connect(DiscoveredPrinter)
    case connectSuccess(UUID, String)
    case connectFailed(PrinterError)
    case disconnect
    case printStart
    case printEnd
    case connectionLost(PrinterError)
}
```

---

## UI Screens

### Home Screen

```
┌─────────────────────────────────────┐
│                           ┌──────┐ │
│                           │  🖨️  │ │
│                           │ [●]  │ │  ← Статус принтера
│                           └──────┘ │
│                                     │
│        ┌─────────────────┐         │
│        │                 │         │
│        │       📷        │         │  ← Большая кнопка камеры
│        │                 │         │
│        └─────────────────┘         │
│                                     │
│ ┌───────────────────────────────┐  │
│ │ 🖼️ Gallery                    │  │  ← Кнопка галереи
│ └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Preview Screen (основной — для ребёнка)

```
┌─────────────────────────────────────┐
│ ←                            ⚙️    │  ← Шестерёнка (открывает settings sheet)
├─────────────────────────────────────┤
│                                     │
│                                     │
│   ┌───────────────────────────┐    │
│   │                           │    │
│   │                           │    │
│   │    [Preview Image]        │    │
│   │                           │    │
│   │                           │    │
│   └───────────────────────────┘    │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐│
│ │           🖨️ Print              ││
│ └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Flow для ребёнка**: выбрал фото → увидел превью → нажал печать. Три действия, ноль настроек.

### Settings Sheet (по нажатию ⚙️)

```
┌─────────────────────────────────────┐
│ ─────                               │  ← Drag indicator
│                                     │
│   ☀️ Brightness                     │
│   ○─────────●─────────○            │
│                                     │
│   ◐ Contrast                        │
│   ○─────────●─────────○            │
│                                     │
│   Style                             │
│   ┌────┐ ┌────┐ ┌────┐ ┌────┐     │
│   │ 📷 │ │ ▦  │ │ 📜 │ │ ⊞  │     │
│   │Photo│ │Sharp│ │Vintg│ │Dot │   │
│   └────┘ └────┘ └────┘ └────┘     │
│                                     │
│   ┌─────────────────────────────┐  │
│   │         Reset to defaults   │  │
│   └─────────────────────────────┘  │
└─────────────────────────────────────┘
```

Настройки сохраняются в UserDefaults — следующие фото используют те же параметры.

### Printing Screen

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│                                     │
│           ┌─────────┐              │
│           │         │              │
│           │  ◠◡◠   │              │  ← Jiji animation
│           │         │              │
│           └─────────┘              │
│                                     │
│         ┌───────────────┐          │
│         │ ████████░░░░  │          │  ← Progress bar
│         └───────────────┘          │
│              67%                    │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### Printer Status Indicator

| State | Indicator | Tap Action |
|-------|-----------|------------|
| `disconnected` | 🔴 | Scan & connect |
| `scanning` | 🟡 (pulse) | — |
| `connecting` | 🟡 (pulse) | — |
| `ready` | 🟢 | Show name |
| `busy` | 🟡 | — |
| `error` | 🔴 | Retry |

---

## Localization

### String Catalog (6 strings)

| Key | EN | RU |
|-----|----|----|
| `button.camera` | Camera | Камера |
| `button.gallery` | Gallery | Галерея |
| `button.print` | Print | Печать |
| `button.reset` | Reset | Сброс |
| `status.connecting` | Connecting... | Подключение... |
| `status.printing` | Printing... | Печать... |

---

## Error Handling

### Rules

1. **No `Any`** — все типы явные
2. **No force unwrap** — `guard let` или `if let`
3. **Typed throws** (Swift 6) — где возможно
4. **Result type** — для sync operations
5. **Async throws** — для async operations

### Pattern

```swift
// ❌ Wrong
func process() throws {
    let data = try? loadData()  // silent failure
    ...
}

// ✅ Correct
func process() async throws(ProcessingError) {
    let data: Data
    do {
        data = try await loadData()
    } catch let error as LoadError {
        throw .invalidImage
    } catch {
        throw .unexpected(error)
    }
    ...
}
```

### Error Recovery

```swift
enum ErrorRecovery {
    case retry(action: () async -> Void)
    case reset
    case none
    
    static func recovery(for error: JijiError) -> ErrorRecovery {
        switch error {
        case is PrinterError:
            return .retry { await printer.reconnect() }
        case is ProcessingError:
            return .reset
        default:
            return .none
        }
    }
}
```

---

## Storage

### UserDefaults

```swift
enum PrinterStorage {
    @AppStorage("lastPrinterID")
    static var lastPrinterID: String?
    
    @AppStorage("lastPrinterName") 
    static var lastPrinterName: String?
}

enum SettingsStorage {
    @AppStorage("brightness")
    static var brightness: Double = 0.05
    
    @AppStorage("contrast")
    static var contrast: Double = 1.1
    
    @AppStorage("algorithm")
    static var algorithm: String = "floydSteinberg"
}
```

Настройки из Settings Sheet автоматически применяются к следующим фото — взрослый настроил один раз, ребёнок просто печатает.

### Auto-reconnect Flow

```
App launch
    │
    ├─→ Check lastPrinterID
    │   │
    │   ├─→ Found: attempt silent reconnect (5s timeout)
    │   │   ├─→ Success: PrinterFSM → ready
    │   │   └─→ Fail: PrinterFSM → disconnected (no error UI)
    │   │
    │   └─→ Not found: PrinterFSM → disconnected
    │
    └─→ Show Home Screen
```

---

## Distribution

### Requirements

- Apple Developer Program ($99/year)
- Device UDID registered in portal
- Ad-hoc Provisioning Profile

### Build & Export

```bash
# 1. Archive
xcodebuild archive \
    -scheme JijiPurinto \
    -archivePath build/JijiPurinto.xcarchive

# 2. Export IPA
xcodebuild -exportArchive \
    -archivePath build/JijiPurinto.xcarchive \
    -exportPath build/ \
    -exportOptionsPlist ExportOptions.plist
```

### ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.yourcompany.jijipurinto</key>
        <string>JijiPurinto Ad Hoc</string>
    </dict>
</dict>
</plist>
```

### Installation Options

| Method | Requires | Refresh |
|--------|----------|---------|
| AltStore | Mac/PC weekly | 7 days |
| Sideloadly | Mac/PC | 7 days (free) / 1 year (paid) |
| Apple Configurator | Mac | — |
| Web manifest (OTA) | HTTPS server | — |

---

## Testing Strategy

### Unit Tests

```
Tests/
├── ImageProcessing/
│   ├── ResizeTests.swift
│   ├── DitherTests.swift
│   └── PipelineTests.swift
│
├── FSM/
│   ├── AppFSMTests.swift
│   ├── AppFSMInvalidTests.swift
│   ├── PrinterFSMTests.swift
│   └── PrinterFSMInvalidTests.swift
│
└── Printer/
    └── CatMXCommandsTests.swift
```

### FSM Test Pattern

```swift
func test_idle_openCamera_transitionsToSelecting() {
    let fsm = AppFSM()
    let next = fsm.transition(from: .idle, event: .openCamera)
    XCTAssertEqual(next, .selecting(source: .camera))
}

func test_idle_print_throwsInvalidTransition() {
    let fsm = AppFSM()
    XCTAssertThrowsError(try fsm.transition(from: .idle, event: .print)) { error in
        XCTAssertTrue(error is FSMError)
    }
}
```

### UI Tests

- Image picker flow (mocked)
- Settings adjustment
- Print flow (mocked BLE)

---

## Dependencies

### None (Zero external dependencies)

Всё на системных фреймворках:
- SwiftUI
- CoreBluetooth
- CoreImage
- Accelerate (vImage)

---

## Milestones

### v0.1 — Skeleton
- [ ] Xcode project setup
- [ ] FSM module with tests
- [ ] Basic navigation (Home → Preview)
- [ ] Placeholder UI

### v0.2 — Image Processing
- [ ] ImageProcessor module
- [ ] All dither algorithms
- [ ] Settings + live preview
- [ ] Unit tests for algorithms

### v0.3 — Printer
- [ ] BLE Manager
- [ ] Cat/MX driver
- [ ] Connect/disconnect flow
- [ ] Print flow
- [ ] Status indicator

### v0.4 — Polish
- [ ] Error handling UI
- [ ] Auto-reconnect
- [ ] Localization (EN/RU)
- [ ] App icon

### v1.0 — Release
- [ ] All tests passing
- [ ] Test on real device + printer
- [ ] Build & distribute via Ad-hoc
