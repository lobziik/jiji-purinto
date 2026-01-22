# Jiji-Purinto (ジジプリント)

Native iOS app for printing photos on a BLE thermal printer with a toddler-friendly interface.

## Features

- **Simple UI**: Three-tap workflow (select photo → preview → print)
- **Image Processing**: Real-time dithering preview with multiple algorithms
- **BLE Printing**: Direct connection to Cat/MX thermal printers
- **Zero Dependencies**: System frameworks only (SwiftUI, CoreBluetooth, Accelerate)

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- Cat/MX family thermal printer (MX05-MX11, GB01-03)

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

**Dither Algorithms:**
| Algorithm | Best For |
|-----------|----------|
| `threshold` | Text, line art |
| `floydSteinberg` | Photos, gradients |
| `atkinson` | Vintage look, less ink |
| `ordered` | Patterns, retro style |

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

Ad-hoc distribution via:

- AltStore (7-day refresh)
- Sideloadly
- Apple Configurator

## Documentation

- [CLAUDE.md](CLAUDE.md) - Development guidelines for Claude Code
- [MILESTONES.md](MILESTONES.md) - Project progress tracking
- [docs/catmx-protocol.md](docs/catmx-protocol.md) - Thermal printer protocol specification

## License

MIT
