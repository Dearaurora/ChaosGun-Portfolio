param(
    [string]$BlenderPath = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$projectPath = Split-Path $PSScriptRoot -Parent
$builderPath = Join-Path $PSScriptRoot "build_sunset_open_ringout_v2_preview.py"
$textureBuilderPath = Join-Path $PSScriptRoot "generate_sunset_runtime_textures.py"
$sourcePath = Join-Path $projectPath "assets\source\sunset_toy_sky_islands\open_ringout_v2_preview.blend"
$assetPath = Join-Path $projectPath "assets\models\generated\sunset_toy_sky_islands\open_ringout_v2_preview.glb"

foreach ($requiredPath in @($BlenderPath, $GodotPath, $builderPath, $textureBuilderPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path not found: $requiredPath"
    }
}

Write-Output "Generating Sunset V3 runtime textures..."
& python $textureBuilderPath

if ($LASTEXITCODE -ne 0) {
    throw "Sunset V3 texture generation failed with exit code $LASTEXITCODE"
}

Write-Output "Building gameplay-aligned Sunset V2 preview layer..."
& $BlenderPath --background --python-exit-code 1 --python $builderPath

if ($LASTEXITCODE -ne 0) {
    throw "Sunset V2 gameplay preview build failed with exit code $LASTEXITCODE"
}

foreach ($outputPath in @($sourcePath, $assetPath)) {
    if (-not (Test-Path -LiteralPath $outputPath)) {
        throw "Expected V2 output was not produced: $outputPath"
    }
}

Write-Output "Importing Sunset V2 gameplay GLB into Godot..."
& $GodotPath --headless --path $projectPath --import

if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE"
}

Write-Output "Generated source: $sourcePath"
Write-Output "Generated asset: $assetPath"
