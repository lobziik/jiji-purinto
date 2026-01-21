# CatMX Protocol Fixes

Анализ различий между работающей TypeScript реализацией (`@opuu/cat-printer`) и текущей Swift реализацией.

---

## Проблема 1: Неверный алгоритм CRC

### Текущий код (НЕПРАВИЛЬНО)

```swift
// CatMXCommands.swift — buildCommand()
var crc: UInt8 = 0
for byte in packet.dropFirst(2) {  // Skip prefix bytes
    crc ^= byte
}
```

Это **простой XOR**, а не CRC8.

### Правильный алгоритм

TypeScript использует **CRC8 с polynomial 0x07**:

```swift
/// Calculates CRC8 checksum with polynomial 0x07.
///
/// - Parameter data: Payload bytes to calculate CRC for.
/// - Returns: CRC8 checksum value.
static func crc8(_ data: [UInt8]) -> UInt8 {
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

### Что считать

CRC считается **только от payload**, не от всего пакета:

```swift
// TypeScript:
crc8(payload)  // ✅ только данные

// Текущий Swift:
for byte in packet.dropFirst(2)  // ❌ cmd + reserved + length + data
```

---

## Проблема 2: Лишние команды startPrint/endPrint

### Текущий код

```swift
// CatMXPrinter.swift — print()
let startCmd = CatMXCommands.startPrint(totalRows: UInt16(totalRows))
try await sendCommand(startCmd, to: characteristic)

for row in 0..<totalRows {
    let lineCmd = CatMXCommands.printLine(rowData: Array(rowData))
    try await sendCommand(lineCmd, to: characteristic)
}

let endCmd = CatMXCommands.endPrint()
try await sendCommand(endCmd, to: characteristic)
```

### Как делает TypeScript (работает)

```typescript
async printBitmap(bitmap) {
    for (let y = 0; y < height; y++) {
        const line = data.slice(lineStart, lineEnd);
        if (line.every(byte => byte === 0)) continue;  // skip empty
        await this.draw(line);  // просто Command.Bitmap (0xA2)
    }
}
// БЕЗ startPrint/endPrint!
```

### Исправление

Убрать `startPrint` и `endPrint`, отправлять только bitmap линии.

---

## Проблема 3: Команды могут быть неверными

### Сравнение command IDs

| Функция | TypeScript | Swift | Совпадает |
|---------|-----------|-------|-----------|
| Bitmap/PrintLine | `0xA2` | `0xA2` | ✅ |
| Feed | `0xA1` | `0xA1` | ✅ |
| Speed | `0xBD` | — | ❓ |
| Energy | `0xAF` | `0xAF` | ✅ |
| ApplyEnergy | `0xBE` | — | ❌ отсутствует |
| SetDpi/Quality | `0xA4` | `0xA4` | ✅ |
| Lattice (start) | `0xA6` | `0xA6` | ✅ |
| GetDeviceState | `0xA3` | `0xA7` | ❌ разные! |
| endPrint | — | `0xA3` | ❌ конфликт! |

### Критическая ошибка

В Swift `endPrint = 0xA3`, но в TypeScript `0xA3` — это `GetDeviceState`!

Возможно принтер интерпретирует `endPrint` как запрос статуса и сбрасывает печать.

---

## Проблема 4: Отсутствует ApplyEnergy

TypeScript после `setEnergy()` вызывает `applyEnergy()`:

```typescript
async prepare(speed: number, energy: number): Promise<void> {
    await this.setSpeed(speed);
    await this.setEnergy(energy);
    await this.applyEnergy();  // ← это важно!
}

async applyEnergy(): Promise<void> {
    const command = this.makeCommand(Command.ApplyEnergy, new Uint8Array([1]));
    await this.write(command);
}
```

Команда `ApplyEnergy = 0xBE` отсутствует в Swift.

---

## План исправлений

### 1. Исправить CRC8

**Файл:** `CatMXCommands.swift`

```swift
/// Calculates CRC8 checksum (polynomial 0x07).
private static func crc8(_ data: [UInt8]) -> UInt8 {
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

static func buildCommand(_ command: Command, data: [UInt8]) -> Data {
    var packet: [UInt8] = commandPrefix  // [0x51, 0x78]
    
    packet.append(command.rawValue)
    packet.append(0x00)  // reserved / CommandType.Transfer
    
    let length = UInt16(data.count)
    packet.append(UInt8(length & 0xFF))
    packet.append(UInt8((length >> 8) & 0xFF))
    
    packet.append(contentsOf: data)
    
    // CRC только от payload!
    packet.append(crc8(data))
    
    packet.append(0xFF)
    
    return Data(packet)
}
```

### 2. Добавить недостающие команды

**Файл:** `CatMXConstants.swift`

```swift
enum Command: UInt8 {
    case getDeviceInfo = 0xA8
    case setQuality = 0xA4      // SetDpi
    case setEnergy = 0xAF       // Energy
    case applyEnergy = 0xBE     // ← ДОБАВИТЬ
    case setSpeed = 0xBD        // ← ДОБАВИТЬ
    case feedPaper = 0xA1       // Feed
    case retract = 0xA0         // ← ДОБАВИТЬ
    case latticeStart = 0xA6    // Lattice (если нужен)
    case printLine = 0xA2       // Bitmap
    case getStatus = 0xA3       // GetDeviceState (НЕ endPrint!)
}
```

### 3. Добавить команды в CatMXCommands

```swift
/// Sets print speed.
static func setSpeed(_ speed: UInt8) -> Data {
    buildCommand(.setSpeed, data: [speed])
}

/// Applies energy settings (must be called after setEnergy).
static func applyEnergy() -> Data {
    buildCommand(.applyEnergy, data: [0x01])
}
```

### 4. Упростить print flow

**Файл:** `CatMXPrinter.swift`

```swift
func print(bitmap: MonoBitmap, onProgress: @escaping (Double) -> Void) async throws {
    guard let blePeripheral = connectedPeripheral,
          let characteristic = writeCharacteristic else {
        throw PrinterError.connectionLost
    }
    
    let totalRows = bitmap.height
    
    // НЕТ startPrint!
    
    for row in 0..<totalRows {
        let rowData = bitmap.row(at: row)
        
        // Пропустить пустые строки (опционально, для скорости)
        if rowData.allSatisfy({ $0 == 0 }) {
            continue
        }
        
        let lineCmd = CatMXCommands.printLine(rowData: Array(rowData))
        try await sendCommand(lineCmd, to: characteristic)
        
        onProgress(Double(row + 1) / Double(totalRows))
    }
    
    // НЕТ endPrint!
    
    // Feed paper at the end
    let feedCmd = CatMXCommands.feedPaper(lines: 40)
    try await sendCommand(feedCmd, to: characteristic)
}
```

### 5. Исправить инициализацию принтера

```swift
func prepare() async throws {
    let speedCmd = CatMXCommands.setSpeed(32)  // или другое значение
    try await sendCommand(speedCmd, to: writeCharacteristic!)
    
    let energyCmd = CatMXCommands.setEnergy(0x60)  // ~24000 в TS это 4 байта
    try await sendCommand(energyCmd, to: writeCharacteristic!)
    
    let applyCmd = CatMXCommands.applyEnergy()  // ← ВАЖНО!
    try await sendCommand(applyCmd, to: writeCharacteristic!)
}
```

---

## Тестирование

### Шаг 1: Проверить feed

Самый простой тест — отправить только feed:

```swift
let feedCmd = CatMXCommands.feedPaper(lines: 50)
try await sendCommand(feedCmd, to: characteristic)
```

Если бумага протянулась — базовая коммуникация работает.

### Шаг 2: Напечатать одну линию

```swift
let blackLine = Array(repeating: UInt8(0xFF), count: 48)  // 384 чёрных пикселя
let lineCmd = CatMXCommands.printLine(rowData: blackLine)
try await sendCommand(lineCmd, to: characteristic)

let feedCmd = CatMXCommands.feedPaper(lines: 20)
try await sendCommand(feedCmd, to: characteristic)
```

Должна напечататься одна чёрная полоса.

### Шаг 3: Полная печать

Если шаги 1-2 работают, пробовать полный bitmap.

---

## Отладка

Добавить логирование hex-данных отправляемых команд:

```swift
printerLogger.debug("CMD: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
```

Сравнить с тем что отправляет TypeScript версия (включить `debug: true`).

---

## Ссылки

- [opuu/cat-printer source](https://github.com/opuu/cat-printer/blob/master/src/cat-printer.ts)
- [opuu/cat-printer enums](https://github.com/opuu/cat-printer/blob/master/src/enums.ts)
- [opuu/cat-printer utils (CRC8)](https://github.com/opuu/cat-printer/blob/master/src/utils.ts)
- [bitbank2/Thermal_Printer](https://github.com/bitbank2/Thermal_Printer) — Arduino reference
