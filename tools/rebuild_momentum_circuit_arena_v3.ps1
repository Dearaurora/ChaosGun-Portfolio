param(
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [switch]$ImportGodot,
    [string]$GodotExe = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot "build_momentum_circuit_arena_v3.py"
$layout = Join-Path $root "resources\maps\momentum_circuit_layout_v2.json"
$blend = Join-Path $root "assets\source\momentum_circuit_v3\momentum_circuit_foreground_v3.blend"
$glb = Join-Path $root "assets\models\generated\momentum_circuit_v3\momentum_circuit_foreground_v3.glb"

foreach ($required in @($BlenderExe, $builder, $layout)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Momentum Circuit rebuild input is missing: $required"
    }
}

$freshestInputUtc = @(
    (Get-Item -LiteralPath $builder).LastWriteTimeUtc,
    (Get-Item -LiteralPath $layout).LastWriteTimeUtc
) | Sort-Object -Descending | Select-Object -First 1

Write-Host "Rebuilding Momentum Circuit v3 visual-only foreground..."
& $BlenderExe --background --python-exit-code 1 --python $builder
if ($LASTEXITCODE -ne 0) {
    throw "Momentum Circuit Blender builder failed with exit code $LASTEXITCODE"
}

foreach ($output in @($blend, $glb)) {
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw "Expected Momentum Circuit output is missing: $output"
    }
    $item = Get-Item -LiteralPath $output
    if ($item.Length -le 0) {
        throw "Expected Momentum Circuit output is empty: $output"
    }
    if ($item.LastWriteTimeUtc -lt $freshestInputUtc.AddSeconds(-1)) {
        throw "Expected Momentum Circuit output is stale: $output"
    }
}

if ($ImportGodot) {
    if ([string]::IsNullOrWhiteSpace($GodotExe)) {
        $candidate = Get-Command godot4 -ErrorAction SilentlyContinue
        if ($null -eq $candidate) {
            $candidate = Get-Command godot -ErrorAction SilentlyContinue
        }
        if ($null -eq $candidate) {
            throw "Godot executable was not found; pass -GodotExe explicitly"
        }
        $GodotExe = $candidate.Source
    }
    if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
        throw "Godot executable not found: $GodotExe"
    }
    & $GodotExe --headless --editor --path $root --import --quit
    if ($LASTEXITCODE -ne 0) {
        throw "Godot import failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Momentum Circuit v3 foreground rebuild completed."
foreach ($output in @($blend, $glb)) {
    $item = Get-Item -LiteralPath $output
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    Write-Host ("  {0} ({1:N0} bytes, sha256={2})" -f $item.FullName, $item.Length, $hash)
}
