# BezNigativa

Базовый Roblox ClickGUI / Xeno compatibility test на Luau.

## Запуск через Xeno

Вставить в executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Repid21/BezNigativa/main/main.lua"))()
```

## Управление

- `RightShift` — открыть / закрыть GUI.
- ЛКМ по верхней панели — перетащить окно.
- `ESP` — показывает 2D-квадрат вокруг других живых игроков.
- `Health Bar` — включает / выключает полоску здоровья рядом с ESP-квадратом.

## Xeno / Drawing API

ESP рисуется через `Drawing.new("Square")`. При запуске GUI показывает статус Drawing API:

- `Drawing API: ready` — ESP должен работать.
- `Drawing API: unavailable in this Xeno build` — текущая сборка executor не предоставляет Drawing API.

## Файл для загрузки

Основной файл: `main.lua`.
