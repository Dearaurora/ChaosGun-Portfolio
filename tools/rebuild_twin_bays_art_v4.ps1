param(
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [switch]$ImportGodot,
    [string]$GodotExe = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot "build_twin_bays_art_v4_review.py"
$promoter = Join-Path $PSScriptRoot "promote_twin_bays_art_v4.py"
$verifier = Join-Path $PSScriptRoot "verify_twin_bays_art_v4_contract.py"
$python = Get-Command python -ErrorAction Stop

foreach ($path in @($BlenderExe, $builder, $promoter, $verifier)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Twin Bays Art V4 rebuild input is missing: $path"
    }
}

Write-Host "[Build isolated deterministic Art V4 candidate]"
& $BlenderExe --background --python-exit-code 1 --python $builder
if ($LASTEXITCODE -ne 0) {
    throw "Twin Bays Art V4 Blender build failed with exit code $LASTEXITCODE"
}

Write-Host "[Promote selected Art V4 candidate]"
& $python.Source $promoter
if ($LASTEXITCODE -ne 0) {
    throw "Twin Bays Art V4 promotion failed with exit code $LASTEXITCODE"
}

Write-Host "[Verify Art V4 production contract]"
& $python.Source $verifier
if ($LASTEXITCODE -ne 0) {
    throw "Twin Bays Art V4 contract failed with exit code $LASTEXITCODE"
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
    & $GodotExe --headless --audio-driver Dummy --editor --path $root --import --quit
    if ($LASTEXITCODE -ne 0) {
        throw "Godot Art V4 import failed with exit code $LASTEXITCODE"
    }
}

$manifest = Join-Path $root "assets\models\generated\twin_bays_splash_arena_v4\twin_bays_splash_arena_v4_manifest.json"
Write-Host "Twin Bays Art V4 rebuild completed."
Write-Host "  Manifest: $manifest"
Write-Host "  Golden updated: false"
