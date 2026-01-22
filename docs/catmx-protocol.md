# Cat/MX Thermal Printer Protocol

Protocol specification for Cat/MX family BLE thermal printers (MX05-MX11, GB01-03).

Based on reverse engineering and the TypeScript reference
implementation [@opuu/cat-printer](https://github.com/opuu/cat-printer).

## Overview

- **Connection**: BLE GATT
- **Print Width**: 384 pixels (48 bytes per row, 1 bit per pixel)
- **Bit Order**: LSB first (leftmost pixel is bit 0 of first byte)
- **Resolution**: ~203 DPI

## BLE Service & Characteristics

| UUID     | Type    | Description                                   |
|----------|---------|-----------------------------------------------|
| `0xAE30` | Service | Main printer service                          |
| `0xAE01` | Write   | Command transmission (write without response) |
| `0xAE02` | Notify  | Status notifications from printer             |

**Note**: Some documentation shows AE01/AE02 reversed. The MX11 uses AE01 for write and AE02 for notify. Test both if
communication fails.

### Discovery

Cat/MX printers do **not** advertise their service UUID during BLE scan. Filter by device name instead:

- Prefixes: `MX`, `GB`, `Cat`
- Examples: `MX05`, `MX11`, `GB01`, `Cat_Printer`

## Packet Format

All commands follow this structure:

```
┌─────────┬─────────┬─────────┬──────────┬───────────┬───────────┬──────────┬─────────┐
│ 0x51    │ 0x78    │ Command │ Reserved │ Length Lo │ Length Hi │ Payload  │ CRC8    │ 0xFF    │
│ (magic) │ (magic) │ (1B)    │ (0x00)   │ (1B)      │ (1B)      │ (N bytes)│ (1B)    │ (end)   │
└─────────┴─────────┴─────────┴──────────┴───────────┴───────────┴──────────┴─────────┴─────────┘
```

| Field    | Size    | Description                           |
|----------|---------|---------------------------------------|
| Magic    | 2 bytes | Always `0x51 0x78`                    |
| Command  | 1 byte  | Command identifier                    |
| Reserved | 1 byte  | Always `0x00`                         |
| Length   | 2 bytes | Payload length (little-endian)        |
| Payload  | N bytes | Command-specific data                 |
| CRC8     | 1 byte  | CRC of payload only (polynomial 0x07) |
| End      | 1 byte  | Always `0xFF`                         |

### CRC8 Algorithm

CRC is calculated **only on the payload data**, not the entire packet:

```swift
func crc8(_ data: [UInt8]) -> UInt8 {
    var crc: UInt8 = 0
    for byte in data {
        crc ^= byte
        for _ in 0..<8 {
            if (crc & 0x80) != 0 {
                crc = (crc << 1) ^ 0x07
            } else {
                crc = crc << 1
            }
        }
    }
    return crc
}
```

**Common mistake**: Using simple XOR instead of proper CRC8 polynomial division.

## Command Reference

### Print Line (0xA2)

Prints a single row of bitmap data.

| Field   | Value                             |
|---------|-----------------------------------|
| Command | `0xA2`                            |
| Payload | 48 bytes (384 pixels, 1 bit each) |

**Bit interpretation**: `1` = black pixel, `0` = white pixel (LSB first, bit 0 = leftmost)

```swift
static func printLine(rowData: [UInt8]) -> Data {
    buildCommand(.printLine, data: rowData)  // 48 bytes
}
```

**Example**: Print a solid black line

```swift
let blackLine = Array(repeating: UInt8(0xFF), count: 48)
let cmd = CatMXCommands.printLine(rowData: blackLine)
// Result: 51 78 A2 00 30 00 [48 x 0xFF] [CRC] FF
```

### Feed Paper (0xA1)

Advances paper by specified number of lines.

| Field   | Value                               |
|---------|-------------------------------------|
| Command | `0xA1`                              |
| Payload | 2 bytes (line count, little-endian) |

```swift
static func feedPaper(lines: UInt16) -> Data {
    let lowByte = UInt8(lines & 0xFF)
    let highByte = UInt8((lines >> 8) & 0xFF)
    return buildCommand(.feedPaper, data: [lowByte, highByte])
}
```

**Typical values**: 40-72 lines (~5-9mm at 203 DPI)

### Retract Paper (0xA0)

Retracts paper (reverse feed).

| Field   | Value                               |
|---------|-------------------------------------|
| Command | `0xA0`                              |
| Payload | 2 bytes (line count, little-endian) |

### Set Quality (0xA4)

Sets print density/quality mode.

| Field   | Value                  |
|---------|------------------------|
| Command | `0xA4`                 |
| Payload | 1 byte (quality level) |

**Quality values**:
| Value | Level |
|-------|-------|
| `0x31` | Light (faster, less ink) |
| `0x32` | Normal |
| `0x33` | Dark (slower, more ink) |

### Set Energy (0xAF)

Sets thermal head energy (heat level).

| Field   | Value                     |
|---------|---------------------------|
| Command | `0xAF`                    |
| Payload | 1 byte (energy 0x00-0xFF) |

**Typical range**: `0x60` - `0x80`

- Lower = lighter print
- Higher = darker print (risk of overheating)

### Apply Energy (0xBE)

**Must be called after `setEnergy()` to activate settings.**

| Field   | Value           |
|---------|-----------------|
| Command | `0xBE`          |
| Payload | 1 byte (`0x01`) |

```swift
static func applyEnergy() -> Data {
    buildCommand(.applyEnergy, data: [0x01])
}
```

### Set Speed (0xBD)

Sets print speed.

| Field   | Value                |
|---------|----------------------|
| Command | `0xBD`               |
| Payload | 1 byte (speed value) |

**Typical value**: `32`

### Get Status (0xA3)

Requests printer status.

| Field   | Value  |
|---------|--------|
| Command | `0xA3` |
| Payload | Empty  |

**Response format**: Same packet structure with status byte in payload.

**Status bits**:
| Bit | Meaning |
|-----|---------|
| `0x00` | Ready |
| `0x01` | Paper error (out/jammed) |
| `0x02` | Overheated |
| `0x04` | Low battery |

### Get Device Info (0xA8)

Requests device information.

| Field   | Value  |
|---------|--------|
| Command | `0xA8` |
| Payload | Empty  |

## Print Flow

### Minimal Print Sequence

```
1. Connect to printer
2. (Optional) Set quality, energy, speed
3. (Optional) Apply energy
4. For each row: send printLine command
5. Feed paper
```

**Important**: No `startPrint` or `endPrint` commands needed. Simply send bitmap lines directly.

### Recommended Initialization

```swift
// 1. Set speed
try await sendCommand(CatMXCommands.setSpeed(32))

// 2. Set energy
try await sendCommand(CatMXCommands.setEnergy(0x60))

// 3. Apply energy (REQUIRED after setEnergy)
try await sendCommand(CatMXCommands.applyEnergy())

// 4. Set quality
try await sendCommand(CatMXCommands.setQuality(.normal))
```

### Print Bitmap

```swift
// Send each row
for row in 0..<bitmap.height {
    let rowData = bitmap.row(at: row)  // 48 bytes
    let cmd = CatMXCommands.printLine(rowData: Array(rowData))
    try await sendCommand(cmd)
}

// Feed paper at end
let feedCmd = CatMXCommands.feedPaper(lines: 72)
try await sendCommand(feedCmd)
```

## Flow Control

### BLE Buffer Management

The printer uses write-without-response for performance. Without flow control, data can be lost when CoreBluetooth's
buffer fills.

**Solution**: Use `canSendWriteWithoutResponse` and `peripheralIsReadyToSendWriteWithoutResponse` delegate callback:

```swift
// Wait for buffer space before each write
func write(data: Data, to characteristic: CBCharacteristic) async throws {
    while !peripheral.canSendWriteWithoutResponse {
        await waitForWriteReady()  // Wait for delegate callback
    }
    peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
}
```

### Timing

If flow control is not implemented, add delay between rows:

- Recommended: 3.5-7.5ms per row
- Adjust based on print quality and buffer overflow symptoms

## Troubleshooting

### Common Issues

| Symptom          | Cause                     | Solution                                    |
|------------------|---------------------------|---------------------------------------------|
| No response      | Wrong characteristic UUID | Try swapping AE01/AE02                      |
| Garbled output   | Wrong CRC calculation     | Use polynomial 0x07, CRC payload only       |
| Mirrored output  | Wrong bit order           | Use LSB first (bit 0 = leftmost pixel)      |
| Partial print    | Buffer overflow           | Implement flow control or add delays        |
| Very light print | Energy too low            | Increase energy value, call applyEnergy()   |
| Nothing prints   | Missing applyEnergy()     | Always call applyEnergy() after setEnergy() |
| Command ignored  | Wrong endianness          | Use little-endian for length/line count     |

### Debug Logging

Log hex data for transmitted commands:

```swift
let hexData = cmd.map {
    String(format: "%02X", $0)
}
.joined(separator: " ")
logger.debug("TX: \(hexData)")
```

Compare with TypeScript reference implementation output.

## References

- [@opuu/cat-printer](https://github.com/opuu/cat-printer) - TypeScript implementation
- [bitbank2/Thermal_Printer](https://github.com/bitbank2/Thermal_Printer) - Arduino reference

## Command Quick Reference

| Command         | ID     | Payload          | Description      |
|-----------------|--------|------------------|------------------|
| Print Line      | `0xA2` | 48 bytes         | Print bitmap row |
| Feed Paper      | `0xA1` | 2 bytes (u16 LE) | Advance paper    |
| Retract         | `0xA0` | 2 bytes (u16 LE) | Retract paper    |
| Set Quality     | `0xA4` | 1 byte           | Print density    |
| Set Energy      | `0xAF` | 1 byte           | Heat level       |
| Apply Energy    | `0xBE` | 1 byte (0x01)    | Activate energy  |
| Set Speed       | `0xBD` | 1 byte           | Print speed      |
| Get Status      | `0xA3` | Empty            | Query status     |
| Get Device Info | `0xA8` | Empty            | Query device     |
