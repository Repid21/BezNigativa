# BezNigativa v7

Исходники разделены на независимые классы. Точка запуска — `main.lua`; папка `src` должна находиться рядом с ней.

```text
main.lua
src/
  App.lua
  core/Config.lua
  core/Janitor.lua
  ui/Window.lua
  features/Combat.lua
  features/Friends.lua
  features/Movement.lua
  features/Visuals.lua
  features/Other.lua
```

Если файлы лежат не в стандартной папке `src`, перед запуском укажите путь:

```lua
getgenv().BezNigativaSourceRoot = "путь/к/src"
```

Настройки автоматически читаются и сохраняются в `BezNigativa/config.json`. Повторный запуск сначала полностью выгружает предыдущий экземпляр.
