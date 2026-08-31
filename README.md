# BezNigativa v9.8

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
  games/Detector.lua
  games/RoleChams.lua
  games/Forsaken.lua
  games/MurderMystery2.lua
  games/AutoDodgeController.lua
  games/UntitledBoxingGame.lua
```

Если файлы лежат не в стандартной папке `src`, перед запуском укажите путь:

```lua
getgenv().BezNigativaSourceRoot = "путь/к/src"
```

Настройки автоматически читаются и сохраняются в `BezNigativa/config.json`. Повторный запуск сначала полностью выгружает предыдущий экземпляр.

## Запуск через инжектор

Корневой `main.lua` загружает классы из `src` напрямую с GitHub. `dist/BezNigativa.lua` является автоматически собранной standalone-версией.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Repid21/BezNigativa/main/main.lua"))()
```

После изменений в классах заново запустите `build.ps1`, чтобы обновить standalone-файл.

Acceptance-тесты Auto Dodge запускаются через `tests/run.ps1` (нужен `luau.exe` в `PATH`).

Поддерживаемые игровые профили определяются по Universe ID: Forsaken, Murder Mystery 2 и Untitled Boxing Game. Для распознанной игры внизу боковой панели появляется отдельная вкладка. В UBG она содержит универсальный Auto Dodge по внутренним `AttackTrail`/`StartupHighlight`, без `AnimationId` и таблиц стилей.
