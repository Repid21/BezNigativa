# Roblox ClickGUI

Базовый ClickGUI для Roblox на Luau.

## Управление
- `Right Shift` — открыть / закрыть ClickGUI.

## Структура
```text
Roblox-ClickGUI/
├─ README.md
├─ LICENSE
├─ .gitignore
└─ src/
   ├─ main.lua
   └─ ui.lua
```

## Использование в Roblox Studio

1. Открой Roblox Studio.
2. Перейди в `StarterPlayer > StarterPlayerScripts`.
3. Создай `LocalScript`.
4. Вставь туда код из `src/main.lua`.

`src/ui.lua` — отдельный вариант, где вся сборка интерфейса вынесена в функцию. Его удобно использовать, если дальше будешь расширять GUI.

## Примечание
Это обычный клиентский Roblox GUI. Сам Dear ImGui внутри Roblox не используется — интерфейс только сделан в похожем минималистичном стиле.
