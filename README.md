# Jiji-Purinto (ジジプリント)

Native iOS app for printing photos on a BLE thermal printer with, presumably, a toddler-friendly interface.

## What's that?

iOS app.

- Three-tap workflow (select a photo → preview → print)
- Dithering preview with couple algorithms
- Direct connection to Cat/MX thermal printer via BLE
- System frameworks only (SwiftUI, CoreBluetooth)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Photo     │ ──► │  Dithering  │ ──► │   Print     │
│   Picker    │     │  Preview    │     │   Button    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                    ┌──────┴──────┐
                    │ BLE → MX11  │
                    │  384px/row  │
                    └─────────────┘
```

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- Cat/MX family thermal printer (MX05-MX11, probably GB01-03)
    - Tested only with MX11

## Similar things and references
- [@opuu/cat-printer](https://github.com/opuu/cat-printer)
- [bitbank2/Thermal_Printer](https://github.com/bitbank2/Thermal_Printer)
- [bitbank2/Print2BLE](https://github.com/bitbank2/Print2BLE)
- https://hackaday.com/tag/mini-printer/

## Build

```bash
# Build
xcodebuild build -scheme jiji-purinto -project jiji-purinto.xcodeproj

# Run tests
xcodebuild test -scheme jiji-purinto -project jiji-purinto.xcodeproj \
    -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

The app uses **FSM (Finite State Machine) + MVVM** architecture with two state machines:

### App Flow (AppFSM)

```
idle → selecting → processing → preview → printing → done
                                                  ↘ error
```

### Printer Connection (PrinterFSM)

```
disconnected → scanning → connecting → ready → busy
                                         ↘ error
```

## Image Processing Pipeline

```
UIImage → Normalize → Resize (384px) → Grayscale → Brightness/Contrast → Dither → MonoBitmap
```

## Printer Protocol

The app targets **Cat/MX family thermal printers** using a proprietary BLE GATT protocol.

- **Print width**: 384 pixels (48 bytes per row)
- **Service UUID**: `0xAE30`
- **Protocol**: See [docs/catmx-protocol.md](docs/catmx-protocol.md)

## Project Structure

```
jiji-purinto/
├── App/                    # Coordinators (FSM ↔ SwiftUI bridge)
├── Core/
│   ├── FSM/               # State machines (AppFSM, PrinterFSM)
│   ├── Storage/           # UserDefaults persistence
│   └── Types/             # Shared types
├── Features/
│   ├── ImageProcessing/   # Pipeline, dither algorithms
│   └── ImagePicker/       # Photo selection
├── Printer/
│   ├── Protocol/          # ThermalPrinter abstraction
│   ├── BLE/               # CoreBluetooth wrapper
│   └── Drivers/CatMX/     # Cat/MX implementation
└── UI/                    # SwiftUI screens and components
```

## Distribution

Ad-hoc. Build yourself.

## Documentation

- [CLAUDE.md](CLAUDE.md) - Development guidelines for Claude Code
- [docs/catmx-protocol.md](docs/catmx-protocol.md) - Thermal printer protocol specification

---
```
FUTURE GADGET #%^?: JIJI-PURINTO
STATUS: OPERATIONAL
DIVERGENCE: ██████ (ACCEPTABLE)

AI assistant helped. Suspicious, but productive.
Cat was present. Cat always present. Coincidence rate: 0%.
```