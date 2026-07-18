[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [switch]$Quick,

    [string]$ReportPath = "res://reports/open_ringout_performance.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Enter-RenderPerformanceGate {
    $mutex = [System.Threading.Mutex]::new($false, "Local\ChaosGun.RenderPerformanceGate")
    try {
        try {
            $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(5))
        } catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
        }
        if (-not $acquired) {
            throw "Timed out waiting for another ChaosGun render performance gate to finish."
        }
        return $mutex
    } catch {
        $mutex.Dispose()
        throw
    }
}

function Exit-RenderPerformanceGate {
    param([System.Threading.Mutex]$Mutex)
    if ($null -eq $Mutex) { return }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
}

function Convert-ResourcePathToFilePath {
    param([string]$ResourcePath)
    if (-not $ResourcePath.StartsWith("res://")) { throw "Expected a res:// path: $ResourcePath" }
    return Join-Path $projectPath ($ResourcePath.Substring(6).Replace("/", [IO.Path]::DirectorySeparatorChar))
}

function Get-ProblemLines {
    param([string]$Output)
    return @($Output -split "`r?`n" | Where-Object { $_ -match "SCRIPT ERROR:|(^|\s)ERROR:|CRASH:" })
}

function Get-CurrentEvidence {
    $paths = [ordered]@{
        open_ringout_scene = "res://scenes/maps/open_ringout_slice.tscn"
        open_ringout_script = "res://scripts/maps/open_ringout_slice.gd"
        hero_glb = "res://assets/models/generated/characters/hero_character_rig_v2.glb"
        projectile_script = "res://scripts/weapons/projectile.gd"
        hud_script = "res://scripts/ui/ringout_hud.gd"
    }
    $result = [ordered]@{}
    foreach ($name in $paths.Keys) {
        $path = $paths[$name]
        $file = Convert-ResourcePathToFilePath $path
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Evidence file is missing: $path" }
        $result[$name] = [ordered]@{ path = $path; sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    return $result
}

function Add-ForegroundInterop {
    if ("ChaosGun.OpenRingoutForeground" -as [type]) { return }
    Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace ChaosGun {
  public static class OpenRingoutForeground {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool SetForegroundWindow(IntPtr hWnd);
  }
}
'@
}

function Restore-ForegroundWindow {
    param([IntPtr]$WindowHandle)
    if ($WindowHandle -ne [IntPtr]::Zero) {
        [void][ChaosGun.OpenRingoutForeground]::SetForegroundWindow($WindowHandle)
    }
}

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
}

$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$reportsPath = Join-Path $projectPath "reports"
$failures = New-Object 'System.Collections.Generic.List[string]'
$runStartedUtc = [DateTime]::UtcNow.ToString("o")
$rawReportResourcePath = "res://reports/open_ringout_performance_raw.json"
$stdoutPath = Join-Path $reportsPath "open_ringout_performance.stdout.log"
$stderrPath = Join-Path $reportsPath "open_ringout_performance.stderr.log"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot executable not found: $GodotPath" }
if (-not $ReportPath.StartsWith("res://reports/") -or -not $ReportPath.EndsWith(".json")) { throw "ReportPath must be a JSON file under res://reports/." }
if (-not (Test-Path -LiteralPath $reportsPath -PathType Container)) { New-Item -ItemType Directory -Path $reportsPath | Out-Null }
$godotExe = (Resolve-Path -LiteralPath $GodotPath).Path
if ($godotExe.EndsWith("_console.exe", [StringComparison]::OrdinalIgnoreCase)) {
    $guiCandidate = $godotExe.Substring(0, $godotExe.Length - "_console.exe".Length) + ".exe"
    if (Test-Path -LiteralPath $guiCandidate -PathType Leaf) { $godotExe = (Resolve-Path -LiteralPath $guiCandidate).Path }
}
$commit = (git -C $projectPath rev-parse HEAD 2>$null).Trim()
if (-not $commit) { $commit = "unknown" }
$currentEvidence = Get-CurrentEvidence
$launcherHash = (Get-FileHash -LiteralPath $godotExe -Algorithm SHA256).Hash.ToLowerInvariant()
Add-ForegroundInterop
$previousForegroundWindow = [ChaosGun.OpenRingoutForeground]::GetForegroundWindow()

foreach ($path in @((Convert-ResourcePathToFilePath $rawReportResourcePath), $stdoutPath, $stderrPath)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}

$warmupSeconds = if ($Quick) { 2.0 } else { 10.0 }
$sampleSeconds = if ($Quick) { 5.0 } else { 60.0 }
$godotArguments = @(
    "--audio-driver", "Dummy",
    "--rendering-method", "forward_plus",
    "--rendering-driver", "d3d12",
    "--disable-vsync",
    "--windowed",
    "--resolution", "1920x1080",
    "--path", $projectPath,
    "-s", "res://scripts/tests/open_ringout_performance.gd",
    "--",
    "--quick=$($Quick.IsPresent.ToString().ToLowerInvariant())",
    "--resolution=1920x1080",
    "--warmup=$warmupSeconds",
    "--sample=$sampleSeconds",
    "--commit=$commit",
    "--report=$rawReportResourcePath"
)

$renderMutex = Enter-RenderPerformanceGate
$process = $null
$stdout = ""
$stderr = ""
$rawReport = $null
try {
    # Only wait on the process launched here. Existing Godot processes are not
    # inspected, terminated, or otherwise disturbed by this gate.
    $process = Start-Process -FilePath $godotExe -ArgumentList $godotArguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -NoNewWindow -PassThru
    try { $process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch { Add-Failure "Benchmark priority could not be set to High: $($_.Exception.Message)" }
    $process.WaitForExit()
    $process.Refresh()
    if ([int]$process.ExitCode -ne 0) { Add-Failure "Open Ring-Out benchmark exited with code $($process.ExitCode)" }
} finally {
    Restore-ForegroundWindow -WindowHandle $previousForegroundWindow
    Exit-RenderPerformanceGate -Mutex $renderMutex
}

if (Test-Path -LiteralPath $stdoutPath) { $stdout = [string](Get-Content -LiteralPath $stdoutPath -Raw) }
if (Test-Path -LiteralPath $stderrPath) { $stderr = [string](Get-Content -LiteralPath $stderrPath -Raw) }
$problemLines = @(Get-ProblemLines "$stdout`n$stderr")
if ($problemLines.Count -gt 0) { Add-Failure "Benchmark emitted $($problemLines.Count) engine/script error line(s)" }
$rawReportFilePath = Convert-ResourcePathToFilePath $rawReportResourcePath
if (-not (Test-Path -LiteralPath $rawReportFilePath -PathType Leaf)) {
    Add-Failure "Benchmark did not produce $rawReportResourcePath"
} else {
    try { $rawReport = Get-Content -LiteralPath $rawReportFilePath -Raw | ConvertFrom-Json } catch { Add-Failure "Raw report is not valid JSON: $($_.Exception.Message)" }
}

$sample = if ($null -ne $rawReport) { $rawReport.sample } else { $null }
if ($null -eq $rawReport -or $null -eq $sample) {
    Add-Failure "Performance report is incomplete"
} else {
    if ([bool]$rawReport.quick -ne $Quick.IsPresent) { Add-Failure "Raw report quick-mode flag does not match wrapper invocation" }
    if ([string]$rawReport.evidence.commit -ne $commit) { Add-Failure "Raw report commit does not match the launch commit" }
    foreach ($name in $currentEvidence.Keys) {
        $reported = $rawReport.evidence.files.$name
        if ($null -eq $reported -or [string]$reported.path -ne [string]$currentEvidence[$name].path -or [string]$reported.sha256 -ne [string]$currentEvidence[$name].sha256) {
            Add-Failure "Raw report evidence is stale or does not bind current $name"
        }
    }
    foreach ($field in @("started_at_utc", "ended_at_utc")) {
        if ([string]::IsNullOrWhiteSpace([string]$rawReport.$field)) { Add-Failure "Raw report is missing $field" }
    }
    try {
        $rawStartedUtc = [DateTime]::Parse([string]$rawReport.started_at_utc).ToUniversalTime()
        $rawEndedUtc = [DateTime]::Parse([string]$rawReport.ended_at_utc).ToUniversalTime()
        $wrapperStartedUtc = [DateTime]::Parse($runStartedUtc).ToUniversalTime()
        if ($rawStartedUtc -lt $wrapperStartedUtc -or $rawEndedUtc -lt $rawStartedUtc) {
            Add-Failure "Raw report timestamps are stale or out of order"
        }
    } catch {
        Add-Failure "Raw report timestamps are invalid: $($_.Exception.Message)"
    }
    if ([string]$rawReport.configuration.rendering_driver -ne "d3d12") { Add-Failure "Reported renderer is not D3D12" }
    if ([string]$rawReport.configuration.rendering_method -ne "forward_plus") { Add-Failure "Reported rendering method is not Forward+" }
    $targetResolution = "[1920,1080]"
    foreach ($field in @("resolution")) {
        if (($rawReport.configuration.$field | ConvertTo-Json -Compress) -ne $targetResolution) { Add-Failure "Reported $field is not 1920x1080" }
    }
    foreach ($field in @("client_size_at_sample_start", "client_size_at_sample_end", "viewport_size_at_sample_start", "viewport_size_at_sample_end")) {
        if (($sample.$field | ConvertTo-Json -Compress) -ne $targetResolution) { Add-Failure "Sample $field is not 1920x1080" }
    }
    if (-not [bool]$sample.focus_at_sample_start -or -not [bool]$sample.focus_at_sample_end -or [bool]$sample.focus_lost_for_material_interval) { Add-Failure "Sample focus evidence is invalid" }
    if ([bool]$sample.minimized_during_sample -or [bool]$sample.wrong_client_size_during_sample -or [bool]$sample.render_activity_lost_during_sample) { Add-Failure "Sample window or render activity evidence is invalid" }
    if ([int]$sample.minimum_active_characters -lt 4 -or [int]$sample.maximum_active_characters -lt 4) { Add-Failure "Sample did not contain four active characters" }
    if ([double]$sample.accepted_sample_seconds -lt $sampleSeconds) { Add-Failure "Accepted sample duration is short" }
    if (-not $Quick -and [double]$sample.accepted_sample_seconds -lt 60.0) { Add-Failure "Formal pass requires 60 accepted seconds after warmup" }
    if ([double]$sample.one_percent_low_fps -lt 60.0) { Add-Failure ("1% low FPS {0:N2} is below 60" -f [double]$sample.one_percent_low_fps) }
    if ([double]$sample.frame_time_p99_ms -gt 16.7) { Add-Failure ("p99 frame time {0:N3} ms exceeds 16.700 ms" -f [double]$sample.frame_time_p99_ms) }
    if ([double]$sample.average_draw_calls -gt 1000.0) { Add-Failure ("Average draw calls {0:N1} exceeds 1000" -f [double]$sample.average_draw_calls) }
    if (-not [bool]$rawReport.passed) { Add-Failure "Raw benchmark reported failure" }
}

$releaseComplete = (-not $Quick) -and ($failures.Count -eq 0)
$finalReport = [ordered]@{
    schema_version = 1
    gate = "open_ringout_dedicated_performance"
    release_complete = $releaseComplete
    quick = $Quick.IsPresent
    start_utc = $runStartedUtc
    end_utc = [DateTime]::UtcNow.ToString("o")
    renderer = [ordered]@{ method = if ($null -ne $rawReport) { $rawReport.configuration.rendering_method } else { $null }; driver = if ($null -ne $rawReport) { $rawReport.configuration.rendering_driver } else { $null }; launcher_path = $godotExe; launcher_sha256 = $launcherHash }
    resolution = @(1920, 1080)
    accepted_seconds_required = $sampleSeconds
    thresholds = [ordered]@{ minimum_one_percent_low_fps = 60.0; maximum_p99_frame_time_ms = 16.7; maximum_average_draw_calls = 1000.0 }
    evidence = [ordered]@{ commit = $commit; files = $currentEvidence }
    sample = $sample
    process_validation = [ordered]@{ exit_code = if ($null -ne $process) { [int]$process.ExitCode } else { $null }; engine_or_script_error_lines = $problemLines; stdout_log = "res://reports/$([IO.Path]::GetFileName($stdoutPath))"; stderr_log = "res://reports/$([IO.Path]::GetFileName($stderrPath))"; raw_report = $rawReportResourcePath; previous_foreground_window_restored = ($previousForegroundWindow -ne [IntPtr]::Zero) }
    failures = @($failures)
    passed = ($failures.Count -eq 0)
}
$finalReportFilePath = Convert-ResourcePathToFilePath $ReportPath
$finalReport | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $finalReportFilePath -Encoding utf8

Write-Output "--- OPEN RING-OUT PERFORMANCE SUMMARY ---"
if ($null -ne $sample) {
    Write-Output ("Rendered FPS: {0:N2}" -f [double]$sample.rendered_fps_average)
    Write-Output ("1% low FPS: {0:N2}" -f [double]$sample.one_percent_low_fps)
    Write-Output ("p99 frame time: {0:N3} ms" -f [double]$sample.frame_time_p99_ms)
    Write-Output ("Average/max draw calls: {0:N1}/{1:N1}" -f [double]$sample.average_draw_calls, [double]$sample.maximum_draw_calls)
    Write-Output ("Average/max active characters: {0:N1}/{1:N1}" -f [double]$sample.average_active_characters, [double]$sample.maximum_active_characters)
}
Write-Output "Performance report: $finalReportFilePath"
if ($Quick) { Write-Output "Quick preflight complete; release_complete=false by contract." }
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Error $failure -ErrorAction Continue }
    throw "Open Ring-Out performance gate failed with $($failures.Count) issue(s)."
}
