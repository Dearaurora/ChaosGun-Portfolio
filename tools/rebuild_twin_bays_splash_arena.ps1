param(
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [switch]$ImportGodot,
    [string]$GodotExe = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot "build_twin_bays_splash_arena.py"
$layout = Join-Path $root "resources\maps\twin_bays_layout_v1.json"
$artProfile = Join-Path $root "resources\maps\twin_bays_art_v3.json"
$tideProfile = Join-Path $root "resources\maps\twin_bays_tide_v1.json"

if (-not (Test-Path -LiteralPath $BlenderExe -PathType Leaf)) {
    throw "Blender 5.1 executable not found: $BlenderExe"
}
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
    throw "Twin Bays Blender builder not found: $builder"
}
if (-not (Test-Path -LiteralPath $layout -PathType Leaf)) {
    throw "Canonical Twin Bays layout not found: $layout"
}
foreach ($profile in @($artProfile, $tideProfile)) {
    if (-not (Test-Path -LiteralPath $profile -PathType Leaf)) {
        throw "Twin Bays production profile not found: $profile"
    }
}

$expectedOutputs = @(
    (Join-Path $root "assets\source\twin_bays_splash_arena\twin_bays_splash_arena.blend"),
    (Join-Path $root "assets\models\generated\twin_bays_splash_arena\twin_bays_splash_arena_hero_kit.glb"),
    (Join-Path $root "assets\models\generated\twin_bays_splash_arena\twin_bays_splash_arena_foreground.glb"),
    (Join-Path $root "assets\models\generated\twin_bays_splash_arena\twin_bays_splash_arena_manifest.json"),
    (Join-Path $root "docs\art-direction\previews\twin_bays_splash_arena_hero_kit.png"),
    (Join-Path $root "docs\art-direction\previews\twin_bays_splash_arena_foreground.png")
)

$freshestInputUtc = @(
    (Get-Item -LiteralPath $builder).LastWriteTimeUtc,
    (Get-Item -LiteralPath $layout).LastWriteTimeUtc,
    (Get-Item -LiteralPath $artProfile).LastWriteTimeUtc,
    (Get-Item -LiteralPath $tideProfile).LastWriteTimeUtc
) | Sort-Object -Descending | Select-Object -First 1

Write-Host "Rebuilding Twin Bays Splash Arena from canonical layout..."
& $BlenderExe --background --python-exit-code 1 --python $builder
if ($LASTEXITCODE -ne 0) {
    throw "Blender builder failed with exit code $LASTEXITCODE"
}

foreach ($output in $expectedOutputs) {
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw "Expected output is missing: $output"
    }
    $item = Get-Item -LiteralPath $output
    if ($item.Length -le 0) {
        throw "Expected output is empty: $output"
    }
    if ($item.LastWriteTimeUtc -lt $freshestInputUtc.AddSeconds(-1)) {
        throw "Expected output is stale: $output"
    }
}

$manifestPath = Join-Path $root "assets\models\generated\twin_bays_splash_arena\twin_bays_splash_arena_manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$layoutSha = (Get-FileHash -LiteralPath $layout -Algorithm SHA256).Hash.ToLowerInvariant()
$artSha = (Get-FileHash -LiteralPath $artProfile -Algorithm SHA256).Hash.ToLowerInvariant()
$tideSha = (Get-FileHash -LiteralPath $tideProfile -Algorithm SHA256).Hash.ToLowerInvariant()
if ([string]$manifest.layout_sha256 -ne $layoutSha `
    -or [string]$manifest.art_profile_sha256 -ne $artSha `
    -or [string]$manifest.tide_profile_sha256 -ne $tideSha) {
    throw "Generated manifest is not bound to the current Layout/Art/Tide fingerprint"
}
if ([int]$manifest.material_count -gt 12) {
    throw "Material budget exceeded: $($manifest.material_count) > 12"
}
if (-not [bool]$manifest.contracts.visual_only -or [bool]$manifest.contracts.collision_in_glb) {
    throw "Generated foreground manifest violates the visual-only/collision contract"
}
if ([double]$manifest.contracts.causeway_visual_width -lt 16.0) {
    throw "Generated foreground does not cover the approved 16-unit safe causeway"
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
    & $GodotExe --headless --editor --path $root --import --quit
    if ($LASTEXITCODE -ne 0) {
        throw "Godot import failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Twin Bays Splash Arena rebuild completed."
foreach ($output in $expectedOutputs) {
    $item = Get-Item -LiteralPath $output
    Write-Host ("  {0} ({1:N0} bytes)" -f $item.FullName, $item.Length)
}
