$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$controllerPath = Join-Path $projectRoot "src/games/AutoDodgeController.lua"
$specPath = Join-Path $PSScriptRoot "AutoDodgeController.spec.lua"
$luauCommand = Get-Command "luau.exe" -ErrorAction SilentlyContinue
$luau = if ($luauCommand) { $luauCommand.Source } else { Join-Path $env:TEMP "codex-luau-cli/bin/luau.exe" }
if (-not (Test-Path -LiteralPath $luau)) { throw "Luau CLI not found. Install luau.exe or add it to PATH." }

$controller = [IO.File]::ReadAllText($controllerPath)
$spec = [IO.File]::ReadAllText($specPath)
$requireLine = 'local AutoDodgeController = require("../src/games/AutoDodgeController")'
if (-not $spec.StartsWith($requireLine)) { throw "Unexpected test entrypoint" }
$embedded = "local AutoDodgeController = (function()`n" + $controller + "`nend)()" + $spec.Substring($requireLine.Length)
$temporaryName = ".AutoDodge-" + [guid]::NewGuid().ToString("N") + ".luau"
$temporaryPath = Join-Path $PSScriptRoot $temporaryName

try {
    [IO.File]::WriteAllText($temporaryPath, $embedded, [Text.UTF8Encoding]::new($false))
    Push-Location $projectRoot
    try { & $luau ("tests/" + $temporaryName) }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
}
