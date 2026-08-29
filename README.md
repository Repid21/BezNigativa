# BezNigativa

Базовый Roblox ClickGUI / executor compatibility test на Luau.

## Запуск через Xeno

Вставить в executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Repid21/BezNigativa/main/main.lua"))()
```

## Управление

- `RightShift` — открыть / закрыть GUI.
- ЛКМ по верхней панели — перетащить окно.
- `Test Module` — безопасный тестовый toggle без игровой логики.

## Что проверяет

Если окно `BezNigativa` появилось, значит Xeno смог:

1. получить raw-файл с GitHub через `game:HttpGet`;
2. выполнить полученный Luau-код через `loadstring`;
3. создать клиентский GUI и обработать клавиатуру/мышь.

Скрипт намеренно использует базовые Roblox/Luau API. `gethui()` используется только если функция доступна; иначе используется fallback.

## Файл для загрузки

Основной файл: `main.lua`.
