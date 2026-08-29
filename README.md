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
Пока пусто.

### Movement
- `Speed` — тест изменения WalkSpeed.
- `Jump` — тест изменения JumpPower / JumpHeight.
- Значения меняются кнопками `-` и `+`.

Movement намеренно работает только в Roblox Studio или в приватном сервере, владельцем которого является LocalPlayer. В обычном публичном сервере эти элементы заблокированы.

### Visual
- `ESP` — 2D-квадрат вокруг других живых игроков.
- `Health Bar` — полоска здоровья рядом с ESP-квадратом.

ESP использует `Drawing.new("Square")`. В меню показывается статус Drawing API.

### Other
Пока пусто.

## Файл для загрузки

Основной файл: `main.lua`.
