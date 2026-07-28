param(
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [string]$GodotExe = "E:\AITools\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot "build_twin_bays_art_v3_full_review.py"
$reviewRoot = Join-Path $root "assets\review\twin_bays_art_v3\full_map"
$foreground = Join-Path $reviewRoot "twin_bays_art_v3_full_foreground.glb"
$manifestPath = Join-Path $reviewRoot "twin_bays_art_v3_full_manifest.json"

foreach ($required in @($BlenderExe, $GodotExe, $builder)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required full-map review tool is missing: $required"
    }
}

& $BlenderExe --background --python-exit-code 1 --python $builder
if ($LASTEXITCODE -ne 0) {
    throw "Art V3 full-map Blender build failed with exit code $LASTEXITCODE"
}
foreach ($output in @($foreground, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $output -PathType Leaf) -or (Get-Item -LiteralPath $output).Length -le 0) {
        throw "Art V3 full-map review output is missing or empty: $output"
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.review.status -ne "candidate_pending_human_approval" `
    -or -not [bool]$manifest.review.production_protection.byte_identical `
    -or [bool]$manifest.review.golden_update_allowed) {
    throw "Art V3 full-map manifest violated the review protection contract"
}
if ([int]$manifest.material_count -gt 12 -or -not [bool]$manifest.contracts.visual_only) {
    throw "Art V3 full-map review exceeded its material or visual-only budget"
}

& $GodotExe --headless --editor --path $root --import --quit
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed for the Art V3 full-map candidate"
}

Write-Output "TWIN_BAYS_ART_V3_FULL_REVIEW_BUILD_PASS"
Write-Output "Production Blend, GLBs, manifest and Golden remain byte-identical."
