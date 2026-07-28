param(
    [string]$BlenderExe = "E:\AITools\blender-5.1.1-windows-x64\blender.exe",
    [string]$GodotExe = "E:\AITools\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot "build_twin_bays_art_v6_review.py"
$manifest = Join-Path $root "assets\review\twin_bays_art_v6\candidate\twin_bays_art_v6_manifest.json"

foreach ($required in @($BlenderExe, $GodotExe, $builder)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Art V6 build dependency is missing: $required"
    }
}

& $BlenderExe --background --python-exit-code 1 --python $builder
if ($LASTEXITCODE -ne 0) {
    throw "Art V6 isolated Blender build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw "Art V6 manifest is missing after build: $manifest"
}
$manifestData = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
if (-not [bool]$manifestData.review.production_and_v5_protection.byte_identical `
    -or [bool]$manifestData.review.golden_update_allowed `
    -or [int]$manifestData.material_count -gt 12 `
    -or [int]$manifestData.production_foreground.mesh_objects -gt 12) {
    throw "Art V6 manifest violated protection, material, or batch budgets"
}

& $GodotExe --headless --audio-driver Dummy --editor --path $root --quit-after 20
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed for the Art V6 isolated candidate"
}

Write-Output "TWIN_BAYS_ART_V6_REVIEW_BUILD_PASS"
Write-Output "Art V4 production, Art V5 candidate, and Golden remain protected."
