param(
    [string]$BlenderPath = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$projectPath = Split-Path $PSScriptRoot -Parent
$builderPath = Join-Path $PSScriptRoot "build_commercial_slice_blender_visuals.py"
$assetPath = Join-Path $projectPath "assets\models\generated\commercial_slice_a\commercial_slice_a_visuals.glb"

if (-not (Test-Path -LiteralPath $BlenderPath)) {
    throw "Blender executable not found: $BlenderPath"
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

if (-not (Test-Path -LiteralPath $builderPath)) {
    throw "Blender builder script not found: $builderPath"
}

Write-Output "Building Blender visual layer..."
& $BlenderPath --background --python $builderPath

if ($LASTEXITCODE -ne 0) {
    throw "Blender visual build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $assetPath)) {
    throw "Expected GLB was not produced: $assetPath"
}

Write-Output "Importing generated GLB into Godot..."
& $GodotPath --headless --path $projectPath --import

if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE"
}

Write-Output "Generated and imported: $assetPath"
