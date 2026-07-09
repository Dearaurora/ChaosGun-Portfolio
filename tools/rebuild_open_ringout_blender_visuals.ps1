param(
    [string]$BlenderPath = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$projectPath = Split-Path $PSScriptRoot -Parent
$builderPath = Join-Path $PSScriptRoot "build_open_ringout_blender_visuals.py"
$assetPath = Join-Path $projectPath "assets\models\generated\open_ringout_slice\open_ringout_visuals.glb"

if (-not (Test-Path -LiteralPath $BlenderPath)) {
    throw "Blender executable not found: $BlenderPath"
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

if (-not (Test-Path -LiteralPath $builderPath)) {
    throw "Blender builder script not found: $builderPath"
}

Write-Output "Building Open Ring-Out Blender visual layer..."
& $BlenderPath --background --python $builderPath

if ($LASTEXITCODE -ne 0) {
    throw "Open Ring-Out Blender visual build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $assetPath)) {
    throw "Expected GLB was not produced: $assetPath"
}

Write-Output "Importing generated Open Ring-Out GLB into Godot..."
& $GodotPath --headless --path $projectPath --import

if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE"
}

Write-Output "Generated and imported: $assetPath"
