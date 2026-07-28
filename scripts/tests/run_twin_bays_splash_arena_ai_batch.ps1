param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [ValidateRange(1, 8)]
    [int]$Rounds = 8,

    [ValidateRange(1.0, 30.0)]
    [double]$DurationSeconds = 30.0,

    [string]$ReportPath = "res://reports/twin_bays_splash_arena_ai_batch.json",

    [switch]$SkipEngagementGate,

    [string]$ExpectedLayoutSha256 = "",

    [string]$ExpectedManifestSha256 = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Enter-GodotLongRunGate {
    $mutex = [System.Threading.Mutex]::new($false, "Local\ChaosGun.RenderPerformanceGate")
    try {
        try {
            $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(10))
        } catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
        }
        if (-not $acquired) {
            throw "Timed out waiting for another ChaosGun long-running Godot gate to finish."
        }
        Write-Host "[Godot long-run gate acquired]"
        return $mutex
    } catch {
        $mutex.Dispose()
        throw
    }
}

function Exit-GodotLongRunGate {
    param([System.Threading.Mutex]$Mutex)
    if ($null -eq $Mutex) { return }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
    Write-Host "[Godot long-run gate released]"
}
$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$projectPath = (Resolve-Path -LiteralPath $projectPath).Path
$reportsPath = Join-Path $projectPath "reports"
$stdoutPath = Join-Path $reportsPath "twin_bays_splash_arena_ai_batch.stdout.log"
$stderrPath = Join-Path $reportsPath "twin_bays_splash_arena_ai_batch.stderr.log"
$layoutPath = Join-Path $projectPath "resources\maps\twin_bays_layout_v1.json"
$manifestPath = Join-Path $projectPath "assets\models\generated\twin_bays_splash_arena_v4\twin_bays_splash_arena_v4_manifest.json"

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}
if (-not $ReportPath.StartsWith("res://reports/") -or -not $ReportPath.EndsWith(".json")) {
    throw "ReportPath must be a JSON file under res://reports/."
}
foreach ($expectedHash in @($ExpectedLayoutSha256, $ExpectedManifestSha256)) {
    if ($expectedHash -and $expectedHash -notmatch '^[0-9a-fA-F]{64}$') {
        throw "Expected artifact hashes must be 64 hexadecimal SHA-256 strings."
    }
}
if (-not (Test-Path -LiteralPath $reportsPath)) {
    New-Item -ItemType Directory -Path $reportsPath | Out-Null
}
foreach ($requiredPath in @($layoutPath, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "AI batch artifact binding input is missing: $requiredPath"
    }
}

$layoutShaBefore = (Get-FileHash -LiteralPath $layoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
$manifestShaBefore = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.layout_sha256 -ne $layoutShaBefore) {
    throw "Generated manifest does not belong to the current Twin Bays layout."
}
if ($ExpectedLayoutSha256 -and $layoutShaBefore -ne $ExpectedLayoutSha256.ToLowerInvariant()) {
    throw "Current layout hash changed before the AI batch."
}
if ($ExpectedManifestSha256 -and $manifestShaBefore -ne $ExpectedManifestSha256.ToLowerInvariant()) {
    throw "Current manifest hash changed before the AI batch."
}

$reportRelativePath = $ReportPath.Substring("res://".Length).Replace("/", [IO.Path]::DirectorySeparatorChar)
$reportFilePath = Join-Path $projectPath $reportRelativePath

foreach ($path in @($stdoutPath, $stderrPath, $reportFilePath)) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

$enforceEngagement = if ($SkipEngagementGate) { "false" } else { "true" }
$godotArguments = @(
    "--headless",
    "--audio-driver", "Dummy",
    "--path", $projectPath,
    "-s", "res://scripts/tests/twin_bays_splash_arena_ai_batch.gd",
    "--",
    "--rounds=$Rounds",
    "--duration=$DurationSeconds",
    "--enforce-engagement=$enforceEngagement",
    "--report=$ReportPath"
)

# Do not use --fixed-fps here. TwinBaysPortal currently uses monotonic wall time
# for its 0.55 s cooldown, so accelerated simulation would invalidate portal QA.
$executionPath = $GodotPath
if ($GodotPath.EndsWith("_console.exe", [StringComparison]::OrdinalIgnoreCase)) {
    $candidate = $GodotPath.Substring(0, $GodotPath.Length - "_console.exe".Length) + ".exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $executionPath = $candidate
    }
}
$longRunMutex = Enter-GodotLongRunGate
try {
$process = Start-Process `
    -FilePath $executionPath `
    -ArgumentList $godotArguments `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -NoNewWindow `
    -PassThru `
    -Wait

$stdout = ""
$stderr = ""
if (Test-Path -LiteralPath $stdoutPath) {
    $content = Get-Content -LiteralPath $stdoutPath -Raw
    if ($null -ne $content) { $stdout = [string]$content }
}
if (Test-Path -LiteralPath $stderrPath) {
    $content = Get-Content -LiteralPath $stderrPath -Raw
    if ($null -ne $content) { $stderr = [string]$content }
}
$combinedOutput = "$stdout`n$stderr"
$engineErrorLines = @(
    $combinedOutput -split "`r?`n" |
        Where-Object { $_ -match "(?i)SCRIPT ERROR:|(^|\s)ERROR:|CRASH:" }
)
$leakWarningLines = @(
    $combinedOutput -split "`r?`n" |
        Where-Object {
            $_ -match "(?i)ObjectDB.*(?:leak|orphan)|resources still in use at exit|orphan(?:ed)? (?:node|object|instance)|RID allocations.*leaked"
        }
)

Write-Output "EXIT=$($process.ExitCode)"
Write-Output "--- STDOUT ---"
if ($stdout) { Write-Output $stdout.TrimEnd() }
Write-Output "--- STDERR ---"
if ($stderr) { Write-Output $stderr.TrimEnd() }

if (Test-Path -LiteralPath $reportFilePath) {
    $report = Get-Content -LiteralPath $reportFilePath -Raw | ConvertFrom-Json
    $processValidation = [pscustomobject]@{
        exit_code = $process.ExitCode
        engine_or_script_error_count = $engineErrorLines.Count
        engine_or_script_error_lines = $engineErrorLines
        shutdown_leak_warning_count = $leakWarningLines.Count
        shutdown_leak_warning_lines = $leakWarningLines
        stdout_log = "res://reports/$([IO.Path]::GetFileName($stdoutPath))"
        stderr_log = "res://reports/$([IO.Path]::GetFileName($stderrPath))"
    }
    $layoutShaAfter = (Get-FileHash -LiteralPath $layoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestShaAfter = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $artifactBinding = [pscustomobject]@{
        layout_path = "res://resources/maps/twin_bays_layout_v1.json"
        layout_sha256 = $layoutShaAfter
        manifest_path = "res://assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_manifest.json"
        manifest_sha256 = $manifestShaAfter
        manifest_layout_sha256 = [string]$manifest.layout_sha256
        stable_during_run = ($layoutShaBefore -eq $layoutShaAfter -and $manifestShaBefore -eq $manifestShaAfter)
    }
    $report | Add-Member -NotePropertyName process_validation -NotePropertyValue $processValidation -Force
    $report | Add-Member -NotePropertyName artifact_binding -NotePropertyValue $artifactBinding -Force
    $report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $reportFilePath -Encoding utf8
} else {
    throw "AI batch did not produce its JSON report: $reportFilePath"
}
} finally {
    Exit-GodotLongRunGate -Mutex $longRunMutex
}

if ($process.ExitCode -ne 0) {
    throw "Twin Bays AI batch exited with code $($process.ExitCode)."
}
if ($engineErrorLines.Count -gt 0) {
    throw "Twin Bays AI batch emitted engine or script errors."
}
if ($leakWarningLines.Count -gt 0) {
    throw "Twin Bays AI batch emitted shutdown leak warnings."
}
if (-not $artifactBinding.stable_during_run) {
    throw "Twin Bays layout or manifest changed while the AI batch was running."
}
if (-not [bool]$report.passed) {
    throw "Twin Bays AI batch JSON report did not record a passing result."
}

Write-Output "AI batch report: $reportFilePath"
