# BezNigativa

Базовый Roblox ClickGUI / Xeno compatibility test на Luau.

## Запуск через Xeno

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Repid21/BezNigativa/main/main.lua"))()
```

## Управление

- `RightShift` — открыть / закрыть GUI.
- ЛКМ по верхней панели — перетащить окно.

## Категории

### Combat
- `AimBot` — плавно поворачивает камеру к ближайшей разрешённой точке внутри FOV.
- `FOV radius` — радиус экранного круга захвата.
- `Smoothness` — плавность движения камеры.
- Зоны можно комбинировать: `Head`, `Neck`, `Body`, `Arms`, `Legs`.
- При нескольких включённых зонах выбирается ближайшая к центру экрана подходящая точка.
- Работает только от первого лица.

Combat намеренно работает только в Roblox Studio или в приватном сервере, владельцем которого является LocalPlayer. В обычном публичном сервере функция заблокирована.

### Movement
- `Speed` — тест изменения WalkSpeed.
- `Jump` — тест изменения JumpPower / JumpHeight.
- Значения меняются кнопками `-` и `+`.

Movement работает только в Roblox Studio или в приватном сервере, владельцем которого является LocalPlayer.

### Visual
- `ESP` — 2D-квадрат вокруг других живых игроков.
- `Health Bar` — полоска здоровья рядом с ESP-квадратом.

ESP и FOV-круг используют Drawing API.

### Other
Пока пусто.

## Файл для загрузки

Основной файл: `main.lua`.