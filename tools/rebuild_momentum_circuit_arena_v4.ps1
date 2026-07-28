param(
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [switch]$ImportGodot,
    [string]$GodotExe = "E:\AITools\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot "build_momentum_circuit_arena_v3.py"
$layout = Join-Path $root "resources\maps\momentum_circuit_layout_v2.json"
$blend = Join-Path $root "assets\source\momentum_circuit_v4\momentum_circuit_foreground_v4.blend"
$glb = Join-Path $root "assets\models\generated\momentum_circuit_v4\momentum_circuit_foreground_v4.glb"

foreach ($required in @($BlenderExe, $builder, $layout)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Momentum Circuit v4 rebuild input is missing: $required"
    }
}

$previousVersion = $env:MC_FOREGROUND_VERSION
try {
    $env:MC_FOREGROUND_VERSION = "4"
    Write-Host "Rebuilding Momentum Circuit v4 visual-only foreground..."
    & $BlenderExe --background --python-exit-code 1 --python $builder
    if ($LASTEXITCODE -ne 0) {
        throw "Momentum Circuit Blender builder failed with exit code $LASTEXITCODE"
    }
}
finally {
    $env:MC_FOREGROUND_VERSION = $previousVersion
}

foreach ($output in @($blend, $glb)) {
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw "Expected Momentum Circuit v4 output is missing: $output"
    }
    if ((Get-Item -LiteralPath $output).Length -le 0) {
        throw "Expected Momentum Circuit v4 output is empty: $output"
    }
}

if ($ImportGodot) {
    & $GodotExe --headless --editor --path $root --import --quit
    if ($LASTEXITCODE -ne 0) {
        throw "Godot import failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Momentum Circuit v4 foreground rebuild completed."
foreach ($output in @($blend, $glb)) {
    $item = Get-Item -LiteralPath $output
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    Write-Host ("  {0} ({1:N0} bytes, sha256={2})" -f $item.FullName, $item.Length, $hash)
}
