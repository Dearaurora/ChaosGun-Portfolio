param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$Profile = "ringout_push",
    [string]$NotesPath = "",
    [string]$WindowResolution = "960x540",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent

function Resolve-FeelProfilePath {
    param(
        [string]$ProfileValue
    )

    if ([string]::IsNullOrWhiteSpace($ProfileValue)) {
        $ProfileValue = "ringout_push"
    }

    if ([System.IO.Path]::IsPathRooted($ProfileValue)) {
        return $ProfileValue
    }

    $relativePath = Join-Path $projectPath $ProfileValue
    if (Test-Path -LiteralPath $relativePath) {
        return $relativePath
    }

    $profileName = [System.IO.Path]::GetFileNameWithoutExtension($ProfileValue)
    return (Join-Path $projectPath ("resources\feel_profiles\{0}.json" -f $profileName))
}

function New-LivePlayNotes {
    param(
        [string]$ProfilePath,
        [string]$TargetPath
    )

    $profileId = [System.IO.Path]::GetFileNameWithoutExtension($ProfilePath)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $TargetPath = Join-Path $projectPath ("reports\feel\live-play\{0}-{1}.md" -f $stamp, $profileId)
    } elseif (-not [System.IO.Path]::IsPathRooted($TargetPath)) {
        $TargetPath = Join-Path $projectPath $TargetPath
    }

    $notesDir = Split-Path $TargetPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($notesDir)) {
        New-Item -ItemType Directory -Force -Path $notesDir | Out-Null
    }

    $content = @"
# ChaosGun Live-Play Notes

Profile: $profileId
Profile path: $ProfilePath
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

| Item | Score 1-5 | Notes |
| --- | ---: | --- |
| Shooter recoil comfort |  |  |
| Hit knockback readability |  |  |
| Ring-out satisfaction |  |  |
| Weapon contrast |  |  |
| Match pacing |  |  |

Most satisfying moment:

Most frustrating moment:

Decision: stronger / softer / keep

"@

    Set-Content -LiteralPath $TargetPath -Value $content -Encoding UTF8
    return $TargetPath
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

$profilePath = Resolve-FeelProfilePath -ProfileValue $Profile
if (-not (Test-Path -LiteralPath $profilePath)) {
    throw "Feel profile not found: $profilePath"
}

$notesFile = New-LivePlayNotes -ProfilePath $profilePath -TargetPath $NotesPath

$args = @(
    "--windowed",
    "--resolution", $WindowResolution,
    "--path", $projectPath,
    "-s", "res://scripts/playtest/commercial_slice_playtest_boot.gd",
    "--",
    "--profile=$profilePath"
)

Write-Output "Profile: $profilePath"
Write-Output "Notes: $notesFile"
Write-Output "Args: $($args -join ' ')"

if ($DryRun) {
    Write-Output "Dry run: Godot was not launched."
    return
}

Start-Process -FilePath $GodotPath -ArgumentList $args -WorkingDirectory $projectPath
