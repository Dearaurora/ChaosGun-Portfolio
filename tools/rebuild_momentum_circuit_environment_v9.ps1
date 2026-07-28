param(
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [switch]$ImportGodot,
    [string]$GodotExe = "C:\Users\Administrator\AppData\Local\AIRunnerTools\Godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot "build_momentum_circuit_environment_v8.py"
$blend = Join-Path $root "assets\source\momentum_circuit_v9\momentum_circuit_environment_v9.blend"
$glb = Join-Path $root "assets\models\generated\momentum_circuit_v9\momentum_circuit_environment_v9.glb"

foreach ($required in @($BlenderExe, $builder)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Momentum Circuit v9 environment input is missing: $required"
    }
}

$previousVersion = $env:MC_ENVIRONMENT_VERSION
try {
    $env:MC_ENVIRONMENT_VERSION = "9"
    Write-Host "Rebuilding Momentum Circuit v9 visual-only environment kit..."
    & $BlenderExe --background --python-exit-code 1 --python $builder
    if ($LASTEXITCODE -ne 0) {
        throw "Momentum Circuit v9 environment builder failed with exit code $LASTEXITCODE"
    }
}
finally {
    $env:MC_ENVIRONMENT_VERSION = $previousVersion
}

foreach ($output in @($blend, $glb)) {
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw "Expected Momentum Circuit v9 environment output is missing: $output"
    }
    if ((Get-Item -LiteralPath $output).Length -le 0) {
        throw "Expected Momentum Circuit v9 environment output is empty: $output"
    }
}

if ($ImportGodot) {
    & $GodotExe --headless --editor --path $root --import --quit
    if ($LASTEXITCODE -ne 0) {
        throw "Godot import failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Momentum Circuit v9 environment rebuild completed."
foreach ($output in @($blend, $glb)) {
    $item = Get-Item -LiteralPath $output
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    Write-Host ("  {0} ({1:N0} bytes, sha256={2})" -f $item.FullName, $item.Length, $hash)
}
