param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$Profile = "resources/feel_profiles/default.json",
    [double]$Seconds = 18.0,
    [int]$Seed = 0,
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"

$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$reportDir = Join-Path $projectPath "reports\feel"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

$profilePath = if ([System.IO.Path]::IsPathRooted($Profile)) { $Profile } else { Join-Path $projectPath $Profile }
if (-not (Test-Path -LiteralPath $profilePath)) {
    throw "Profile not found: $profilePath"
}

if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $profileName = [System.IO.Path]::GetFileNameWithoutExtension($profilePath)
    $OutPath = Join-Path $reportDir ("probe-{0}.json" -f $profileName)
} elseif (-not [System.IO.Path]::IsPathRooted($OutPath)) {
    $OutPath = Join-Path $projectPath $OutPath
}

$args = @(
    "--headless",
    "--path", $projectPath,
    "-s", "res://scripts/tests/feel_tuning_probe.gd",
    "--",
    "--profile=$profilePath",
    "--seconds=$Seconds",
    "--seed=$Seed",
    "--out=$OutPath"
)

& $GodotPath @args
if ($LASTEXITCODE -ne 0) {
    throw "Feel tuning probe failed with exit code $LASTEXITCODE"
}

Write-Output "Probe report: $OutPath"
