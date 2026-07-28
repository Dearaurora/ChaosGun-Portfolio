[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$RunId = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$projectPath = (Resolve-Path -LiteralPath $projectPath).Path
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}
if (-not $RunId) {
    $RunId = "$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))-captures-pid$PID"
}
if ($RunId -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{2,127}$') {
    throw "RunId contains unsupported characters: $RunId"
}

$runRelative = "reports/momentum_circuit_release_validation/$RunId"
$runPath = Join-Path $projectPath ($runRelative.Replace('/', '\'))
$manifestPath = Join-Path $runPath "visual_capture_manifest.json"
if (Test-Path -LiteralPath $runPath) {
    throw "Refusing to reuse immutable capture run: $runPath"
}
New-Item -ItemType Directory -Path (Join-Path $runPath "entries") -Force | Out-Null

$matrix = @(
    [ordered]@{ id = "empty_arena"; mode = "empty"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "battle_overview"; mode = "battle"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1920; height = 1080; framing = "overview"; weapon = "" },
    [ordered]@{ id = "battle_hud"; mode = "battle"; mechanism = "warning"; phase = 0.50; cloud = 6.0; width = 1280; height = 720; framing = "overview"; weapon = "" },
    [ordered]@{ id = "mechanism_stable"; mode = "empty"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "mechanism_warning"; mode = "empty"; mechanism = "warning"; phase = 0.50; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "mechanism_switching"; mode = "empty"; mechanism = "switching"; phase = 0.50; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "mechanism_new_bridge"; mode = "empty"; mechanism = "new_bridge"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "teleport_cooldown_0"; mode = "empty"; mechanism = "teleport_empty"; phase = 0.00; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "teleport_cooldown_50"; mode = "empty"; mechanism = "teleport_half"; phase = 0.50; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "teleport_cooldown_100"; mode = "empty"; mechanism = "teleport_ready"; phase = 1.00; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "teleport_trail"; mode = "empty"; mechanism = "teleport_trail"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "trajectory_pistol"; mode = "battle"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "pistol" },
    [ordered]@{ id = "trajectory_smg"; mode = "battle"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "smg" },
    [ordered]@{ id = "trajectory_ak_rifle"; mode = "battle"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "ak_rifle" },
    [ordered]@{ id = "trajectory_shotgun"; mode = "battle"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "shotgun" },
    [ordered]@{ id = "trajectory_gatling"; mode = "battle"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "gatling" },
    [ordered]@{ id = "trajectory_sniper"; mode = "battle"; mechanism = "stable"; phase = 0.40; cloud = 6.0; width = 1536; height = 1024; framing = "overview"; weapon = "sniper" },
    [ordered]@{ id = "cloud_frame_00"; mode = "empty"; mechanism = "stable"; phase = 0.40; cloud = 0.0; width = 1536; height = 1024; framing = "overview"; weapon = "" },
    [ordered]@{ id = "cloud_frame_01"; mode = "empty"; mechanism = "stable"; phase = 0.40; cloud = 14.0; width = 1536; height = 1024; framing = "overview"; weapon = "" }
)

foreach ($entry in $matrix) {
    $entryRelative = "res://$runRelative/entries/$($entry.id).json"
    $arguments = @(
        "--audio-driver", "Dummy",
        "--rendering-method", "forward_plus",
        "--disable-vsync",
        "--windowed", "--resolution", "960x540",
        "--path", $projectPath,
        "--script", "res://scripts/tests/capture_momentum_circuit_arena.gd",
        "--",
        "--capture-id=$($entry.id)",
        "--run-id=$RunId",
        "--mode=$($entry.mode)",
        "--mechanism=$($entry.mechanism)",
        "--phase-progress=$($entry.phase)",
        "--cloud-time=$($entry.cloud)",
        "--width=$($entry.width)",
        "--height=$($entry.height)",
        "--framing=$($entry.framing)",
        "--weapon=$($entry.weapon)",
        "--manifest-entry=$entryRelative",
        "--settle=2.0"
    )
    Write-Host "[Capture $($entry.id)]"
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $GodotPath @arguments 2>&1
    $captureExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    $output | ForEach-Object { Write-Host $_ }
    if ($captureExitCode -ne 0 -or -not ($output -match 'MOMENTUM_CIRCUIT_ARENA_CAPTURE_OK')) {
        throw "Capture failed: $($entry.id)"
    }
}

$captureEntries = @()
foreach ($entry in $matrix) {
    $entryPath = Join-Path $runPath "entries\$($entry.id).json"
    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        throw "Capture manifest entry is missing: $entryPath"
    }
    $captureEntries += Get-Content -Raw -LiteralPath $entryPath | ConvertFrom-Json
}
$manifest = [ordered]@{
    schema_version = 1
    run_id = $RunId
    captures = $captureEntries
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
}
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$manifestRelative = "res://$runRelative/visual_capture_manifest.json"
$verifyArguments = @(
    "--headless", "--audio-driver", "Dummy",
    "--path", $projectPath,
    "--script", "res://scripts/tests/momentum_circuit_visual_evidence_verifier.gd",
    "--", "--input=$manifestRelative"
)
$verifyOutput = & $GodotPath @verifyArguments 2>&1
$verifyOutput | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0 -or -not ($verifyOutput -match 'RESULT momentum_circuit_visual_evidence passed=true')) {
    throw "Momentum Circuit visual capture matrix verification failed"
}

Write-Host "CAPTURE_MATRIX_PASS|run_id=$RunId|captures=$($matrix.Count)|manifest=$manifestPath"
