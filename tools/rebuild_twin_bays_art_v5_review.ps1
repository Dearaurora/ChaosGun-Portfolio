param(
    [string]$BlenderExe = "E:\AITools\blender-5.1.1-windows-x64\blender.exe",
    [string]$GodotExe = "E:\AITools\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe",
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$causticBuilder = Join-Path $PSScriptRoot "generate_twin_bays_v5_caustics.py"
$arenaBuilder = Join-Path $PSScriptRoot "build_twin_bays_art_v5_review.py"
$texture = Join-Path $root "assets\textures\generated\twin_bays_v5_caustics.png"
$manifest = Join-Path $root "assets\review\twin_bays_art_v5\candidate\twin_bays_art_v5_manifest.json"

foreach ($required in @($BlenderExe, $GodotExe, $causticBuilder, $arenaBuilder)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Art V5 build dependency is missing: $required"
    }
}

& $PythonExe $causticBuilder
if ($LASTEXITCODE -ne 0) {
    throw "Art V5 deterministic caustic build failed with exit code $LASTEXITCODE"
}
$firstTextureHash = (Get-FileHash -LiteralPath $texture -Algorithm SHA256).Hash
& $PythonExe $causticBuilder | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Art V5 deterministic caustic rebuild failed with exit code $LASTEXITCODE"
}
$secondTextureHash = (Get-FileHash -LiteralPath $texture -Algorithm SHA256).Hash
if ($firstTextureHash -ne $secondTextureHash) {
    throw "Art V5 caustic texture is not byte deterministic"
}

& $BlenderExe --background --python-exit-code 1 --python $arenaBuilder
if ($LASTEXITCODE -ne 0) {
    throw "Art V5 isolated Blender build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw "Art V5 manifest is missing after build: $manifest"
}
$manifestData = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
if (-not [bool]$manifestData.review.production_protection.byte_identical `
    -or [bool]$manifestData.review.golden_update_allowed `
    -or [int]$manifestData.material_count -gt 12) {
    throw "Art V5 manifest violated production protection or material budget"
}
if ([string]$manifestData.runtime_textures.backdrop_caustics.sha256 -ne $secondTextureHash.ToLowerInvariant()) {
    throw "Art V5 manifest does not bind the deterministic caustic texture"
}

& $GodotExe --headless --audio-driver Dummy --editor --path $root --quit-after 20
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed for the Art V5 isolated candidate"
}

Write-Output "TWIN_BAYS_ART_V5_REVIEW_BUILD_PASS"
Write-Output "Art V4 production and Golden remain byte-identical."
Write-Output "Caustic texture SHA256: $secondTextureHash"
