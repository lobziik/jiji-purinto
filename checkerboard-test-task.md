# Тестовый паттерн: Шахматка 5 см

## Цель

Создать отладочный принт для калибровки:
- Проверка геометрии (клетки должны быть квадратными)
- Проверка протяжки бумаги (нет растяжения/сжатия)
- Проверка bit/byte order (шахматка, не полосы)

---

## Параметры принтера

| Параметр | Значение |
|----------|----------|
| Разрешение | 203 DPI = **8 точек/мм** |
| Ширина печати | 384 px = 48 мм |
| Байт на строку | 48 bytes |

---

## Требования к паттерну

| Параметр | Значение | Расчёт |
|----------|----------|--------|
| Размер клетки | 2 × 2 мм | — |
| Клетка в пикселях | **16 × 16 px** | 2 мм × 8 px/мм |
| Длина отпечатка | 50 мм (5 см) | — |
| Высота в пикселях | **400 rows** | 50 мм × 8 px/мм |
| Клеток по ширине | 24 шт | 384 px ÷ 16 px |
| Клеток по высоте | 25 шт | 400 px ÷ 16 px |

---

## Алгоритм генерации

```swift
/// Generates 5cm checkerboard pattern with 2x2mm cells.
///
/// - Returns: Bitmap data (400 rows × 48 bytes)
static func checkerboard5cm() -> (data: Data, height: Int) {
    let cellSize = 16          // 2mm × 8 dpi = 16 pixels
    let totalHeight = 400      // 50mm × 8 dpi = 400 rows
    let widthBytes = 48        // 384 pixels ÷ 8
    
    var data = Data()
    data.reserveCapacity(totalHeight * widthBytes)
    
    for y in 0..<totalHeight {
        let cellY = y / cellSize           // какая клетка по вертикали
        let evenRow = (cellY % 2) == 0     // чётный ряд клеток?
        
        var row = [UInt8]()
        row.reserveCapacity(widthBytes)
        
        for byteIndex in 0..<widthBytes {
            // Каждый байт = 8 пикселей
            // Клетка = 16 пикселей = 2 байта
            let cellX = byteIndex / 2      // какая клетка по горизонтали
            let evenCol = (cellX % 2) == 0 // чётный столбец клеток?
            
            // Шахматка: чёрная если (evenRow XOR evenCol)
            let isBlack = evenRow != evenCol
            
            row.append(isBlack ? 0xFF : 0x00)
        }
        
        data.append(contentsOf: row)
    }
    
    return (data, totalHeight)
}
```

---

## Ожидаемый результат

```
48 мм (ширина принтера)
├────────────────────────────────────────────┤

██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██   ┐
██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██   │ 2мм
  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██ │
  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██ ┘ 2мм
██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██
...
(25 рядов клеток × 2мм = 50мм)
```

---

## Проверка результата

Измерить линейкой:

| Что измерить | Ожидание | Проблема если |
|--------------|----------|---------------|
| Ширина клетки | 2 мм | ≠2мм → bit order неверный |
| Высота клетки | 2 мм | <2мм → лишние строки, >2мм → пропуск строк |
| Общая длина | 50 мм | ≠50мм → проблема с feed/протяжкой |
| Форма | Квадрат | Прямоугольник → растяжение по одной оси |

---

## Размер данных

- Rows: 400
- Bytes per row: 48
- Total: **19 200 bytes** (~19 KB)

---

## Протяжка после паттерна

### Требование

После печати паттерна — протяжка **4 мм** чтобы изображение вышло из-под головки и можно было оторвать.

### Расчёт

| Параметр | Значение | Расчёт |
|----------|----------|--------|
| Отступ | 4 мм | — |
| В пикселях | **32 rows** | 4 мм × 8 px/мм |

### Реализация

После отправки всех строк изображения — отправить команду `feedPaper`:

```swift
// После печати изображения
let feedLines: UInt16 = 32  // 4mm × 8 dpi
let feedCmd = CatMXCommands.feedPaper(lines: feedLines)
try await sendCommand(feedCmd, to: characteristic)
```

### Константа

Добавить в `CatMXConstants.swift`:

```swift
/// Default gap between prints (4mm = 32 rows at 203 DPI)
static let defaultFeedLines: UInt16 = 32
```

### Использование в print flow

```swift
func print(bitmap: MonoBitmap, onProgress: @escaping (Double) -> Void) async throws {
    // ... отправка строк bitmap ...
    
    // Отступ после печати
    let feedCmd = CatMXCommands.feedPaper(lines: CatMXConstants.defaultFeedLines)
    try await sendCommand(feedCmd, to: characteristic)
}
```

### Альтернатива: пустые строки в данных

Если `feedPaper` не работает стабильно, можно добавить пустые строки в сам bitmap:

```swift
// Добавить 32 пустых строки в конец данных
let emptyRow = Array(repeating: UInt8(0x00), count: 48)
for _ in 0..<32 {
    data.append(contentsOf: emptyRow)
}
```

Но `feedPaper` команда предпочтительнее — быстрее и не греет головку.
