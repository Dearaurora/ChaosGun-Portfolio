param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$ProfileDir = "resources/feel_profiles",
    [string[]]$Profiles = @(),
    [int]$Runs = 3,
    [double]$Seconds = 18.0,
    [int]$SeedBase = 240428,
    [string]$OutPath = "reports/feel/batch-latest.json"
)

$ErrorActionPreference = "Stop"

if ($Runs -lt 1) {
    throw "Runs must be at least 1."
}

$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$profileRoot = if ([System.IO.Path]::IsPathRooted($ProfileDir)) { $ProfileDir } else { Join-Path $projectPath $ProfileDir }
$batchPath = if ([System.IO.Path]::IsPathRooted($OutPath)) { $OutPath } else { Join-Path $projectPath $OutPath }
$batchDir = Split-Path $batchPath -Parent
New-Item -ItemType Directory -Force -Path $batchDir | Out-Null

$profileFiles = Get-ChildItem -LiteralPath $profileRoot -Filter "*.json" | Sort-Object Name
if ($Profiles.Count -gt 0) {
    $wanted = @{}
    foreach ($profileName in $Profiles) {
        foreach ($rawName in $profileName.Split(",")) {
            $normalized = [System.IO.Path]::GetFileNameWithoutExtension($rawName.Trim())
            if (-not [string]::IsNullOrWhiteSpace($normalized)) {
                $wanted[$normalized] = $true
            }
        }
    }
    $filteredProfiles = @()
    foreach ($profile in $profileFiles) {
        if ($null -eq $profile) {
            continue
        }
        $baseName = [string]$profile.BaseName
        if (-not [string]::IsNullOrWhiteSpace($baseName) -and $wanted.ContainsKey($baseName)) {
            $filteredProfiles += $profile
        }
    }
    $profileFiles = $filteredProfiles
    $found = @{}
    foreach ($profile in $profileFiles) {
        $found[[string]$profile.BaseName] = $true
    }
    $missing = @()
    foreach ($name in $wanted.Keys) {
        if (-not $found.ContainsKey($name)) {
            $missing += $name
        }
    }
    if ($missing.Count -gt 0) {
        throw ("Requested profiles not found in {0}: {1}" -f $profileRoot, ($missing -join ', '))
    }
}
if ($profileFiles.Count -eq 0) {
    throw "No profiles found in $profileRoot"
}

$results = @()
foreach ($profile in $profileFiles) {
    for ($run = 1; $run -le $Runs; $run++) {
        $seed = $SeedBase + $run
        $probeOut = Join-Path $batchDir ("probe-{0}-run{1}.json" -f $profile.BaseName, $run)
        & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run_feel_tuning_probe.ps1") -GodotPath $GodotPath -Profile $profile.FullName -Seconds $Seconds -Seed $seed -OutPath $probeOut | Write-Output
        $result = Get-Content -LiteralPath $probeOut -Raw | ConvertFrom-Json
        $result | Add-Member -NotePropertyName run -NotePropertyValue $run
        $results += $result
    }
}

$batch = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    runs_per_profile = $Runs
    seconds = $Seconds
    seed_base = $SeedBase
    results = $results
}

$batch | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $batchPath -Encoding UTF8
Write-Output "Batch report: $batchPath"
