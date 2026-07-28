param(
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [switch]$ImportGodot,
    [string]$GodotExe = "E:\AITools\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot "build_twin_bays_art_v3_hero_review.py"
$manifestPath = Join-Path $root "assets\review\twin_bays_art_v3\twin_bays_art_v3_hero_review_manifest.json"

foreach ($path in @($BlenderExe, $builder)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Hero review input is missing: $path" }
}

& $BlenderExe --background --python-exit-code 1 --python $builder
if ($LASTEXITCODE -ne 0) { throw "Art V3 Hero review build failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Art V3 Hero review manifest is missing" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if (-not [bool]$manifest.production_protection.byte_identical `
    -or [bool]$manifest.contracts.production_foreground_overwritten `
    -or [bool]$manifest.contracts.golden_update_allowed) {
    throw "Art V3 Hero review violated the production protection contract"
}
if ([int]$manifest.exported.mesh_objects -gt 10) { throw "Art V3 Hero GLB exceeds the review mesh budget" }

if ($ImportGodot) {
    if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw "Godot executable is missing: $GodotExe" }
    & $GodotExe --headless --editor --path $root --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot import failed with exit code $LASTEXITCODE" }
}

Write-Output "TWIN_BAYS_ART_V3_HERO_BUILD_PASS"
Write-Output "Manifest: $manifestPath"
