param(
    [string]$BlenderPath = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$projectPath = Split-Path $PSScriptRoot -Parent
$builderPath = Join-Path $PSScriptRoot "build_sunset_toy_sky_islands_hero.py"
$sourcePath = Join-Path $projectPath "assets\source\sunset_toy_sky_islands\sunset_hero_slice.blend"
$assetPath = Join-Path $projectPath "assets\models\generated\sunset_toy_sky_islands\sunset_hero_slice.glb"
$previewPath = Join-Path $projectPath "docs\art-direction\previews\sunset_hero_slice_v1.png"

foreach ($requiredPath in @($BlenderPath, $GodotPath, $builderPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path not found: $requiredPath"
    }
}

Write-Output "Building Sunset Toy Sky Islands hero slice..."
& $BlenderPath --background --python-exit-code 1 --python $builderPath

if ($LASTEXITCODE -ne 0) {
    throw "Sunset hero build failed with exit code $LASTEXITCODE"
}

foreach ($outputPath in @($sourcePath, $assetPath, $previewPath)) {
    if (-not (Test-Path -LiteralPath $outputPath)) {
        throw "Expected hero-slice output was not produced: $outputPath"
    }
}

Write-Output "Importing Sunset hero GLB into Godot..."
& $GodotPath --headless --path $projectPath --import

if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE"
}

Write-Output "Generated source: $sourcePath"
Write-Output "Generated asset: $assetPath"
Write-Output "Generated preview: $previewPath"
