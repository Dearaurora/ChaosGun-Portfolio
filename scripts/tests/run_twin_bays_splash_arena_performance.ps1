[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [ValidateRange(1.0, 10.0)]
    [double]$WarmupSeconds = 10.0,

    [ValidateRange(3.0, 60.0)]
    [double]$SampleSeconds = 60.0,

    [ValidateRange(0, 60)]
    [int]$CooldownSeconds = 30,

    [ValidatePattern("^\d{2,4}x\d{2,4}$")]
    [string]$WindowResolution = "1920x1080",

    [string]$ReportPath = "res://reports/twin_bays_splash_arena_performance.json",

    [switch]$VisibleWindowApproved,

    [string]$VisibleWindowApprovalReason = ""
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
        Write-Host "[Render performance gate acquired]"
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
    Write-Host "[Render performance gate released]"
}

function Assert-NoCompetingChaosGunGodot {
    $projectToken = $projectPath.ToLowerInvariant()
    $competing = @()
    $querySucceeded = $false
    $lastQueryError = $null
    foreach ($attempt in 1..4) {
        try {
            $competing = @(
                Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" -ErrorAction Stop |
                    Where-Object {
                        $commandLine = [string]$_.CommandLine
                        $commandLine -and $commandLine.ToLowerInvariant().Contains($projectToken)
                    }
            )
            $querySucceeded = $true
            break
        } catch {
            $lastQueryError = $_.Exception.Message
            if ($attempt -lt 4) {
                Start-Sleep -Seconds 1
            }
        }
    }
    if (-not $querySucceeded) {
        throw (
            "Windows process isolation query failed after four attempts; " +
            "performance evidence cannot be trusted. Last error: $lastQueryError"
        )
    }
    if ($competing.Count -gt 0) {
        $descriptions = @(
            $competing | ForEach-Object {
                "PID=$($_.ProcessId) $([string]$_.CommandLine)"
            }
        )
        throw (
            "A competing ChaosGun Godot workload is already running. " +
            "Performance evidence would be contaminated; retry after it exits.`n" +
            ($descriptions -join "`n")
        )
    }
}

$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$reportsPath = Join-Path $projectPath "reports"
$failures = New-Object 'System.Collections.Generic.List[string]'
$artifactInputPaths = [ordered]@{
    project = (Join-Path $projectPath "project.godot")
    layout = (Join-Path $projectPath "resources\maps\twin_bays_layout_v1.json")
    art = (Join-Path $projectPath "resources\maps\twin_bays_art_v4.json")
    tide = (Join-Path $projectPath "resources\maps\twin_bays_tide_v1.json")
    twin_manifest = (Join-Path $projectPath "assets\models\generated\twin_bays_splash_arena_v4\twin_bays_splash_arena_v4_manifest.json")
    twin_foreground = (Join-Path $projectPath "assets\models\generated\twin_bays_splash_arena_v4\twin_bays_splash_arena_v4_foreground.glb")
    open_manifest = (Join-Path $projectPath "assets\source\open_ringout_art_v3\open_ringout_art_v3_manifest.json")
    open_scene = (Join-Path $projectPath "scenes\maps\open_ringout_slice.tscn")
    twin_scene = (Join-Path $projectPath "scenes\maps\twin_bays_splash_arena.tscn")
    twin_arena_script = (Join-Path $projectPath "scripts\maps\twin_bays_splash_arena.gd")
    tide_controller = (Join-Path $projectPath "scripts\maps\twin_bays_tide_controller.gd")
    shallow_water = (Join-Path $projectPath "scripts\maps\twin_bays_shallow_water.gd")
    splash_backdrop = (Join-Path $projectPath "scripts\maps\twin_bays_splash_backdrop.gd")
    water_materials = (Join-Path $projectPath "scripts\maps\twin_bays_water_materials.gd")
    water_master_shader = (Join-Path $projectPath "assets\shaders\twin_bays_water_master_v4.gdshader")
    backdrop_water_shader = (Join-Path $projectPath "assets\shaders\twin_bays_backdrop_water_v4.gdshader")
    benchmark_script = (Join-Path $projectPath "scripts\tests\twin_bays_splash_arena_performance.gd")
    benchmark_wrapper = $PSCommandPath
}
$resolutionParts = $WindowResolution -split "x"
$windowWidth = [int]$resolutionParts[0]
$windowHeight = [int]$resolutionParts[1]
if ($windowWidth -lt 320 -or $windowHeight -lt 180) {
    throw "WindowResolution must be at least 320x180."
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}
if (-not $VisibleWindowApproved -or [string]::IsNullOrWhiteSpace($VisibleWindowApprovalReason)) {
    throw (
        "The formal D3D12 performance gate needs a normal 960x540 visible Godot host " +
        "to expose draw-call and primitive counters. Workspace safety requires explicit " +
        "user approval; pass -VisibleWindowApproved and -VisibleWindowApprovalReason."
    )
}
$performanceGodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
if ($performanceGodotPath.EndsWith("_console.exe", [StringComparison]::OrdinalIgnoreCase)) {
    $guiCandidate = $performanceGodotPath.Substring(
        0,
        $performanceGodotPath.Length - "_console.exe".Length
    ) + ".exe"
    if (Test-Path -LiteralPath $guiCandidate -PathType Leaf) {
        # The small Windows console launcher may return before the render process
        # has flushed its report. Wait on the real engine executable so a zero
        # exit code, logs, and JSON all describe the same completed sample.
        $performanceGodotPath = (Resolve-Path -LiteralPath $guiCandidate).Path
    }
}
$performanceLauncherSha256 = (Get-FileHash -LiteralPath $performanceGodotPath -Algorithm SHA256).Hash.ToLowerInvariant()
if (-not $ReportPath.StartsWith("res://reports/") -or -not $ReportPath.EndsWith(".json")) {
    throw "ReportPath must be a JSON file under res://reports/."
}
if (-not (Test-Path -LiteralPath $reportsPath)) {
    New-Item -ItemType Directory -Path $reportsPath | Out-Null
}

function Convert-ResourcePathToFilePath {
    param([string]$ResourcePath)
    $relativePath = $ResourcePath.Substring("res://".Length).Replace("/", [IO.Path]::DirectorySeparatorChar)
    return Join-Path $projectPath $relativePath
}

function Get-PerformanceArtifactBinding {
    $binding = [ordered]@{}
    foreach ($entry in $artifactInputPaths.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
            throw "Performance artifact input is missing: $($entry.Value)"
        }
        $resolved = (Resolve-Path -LiteralPath $entry.Value).Path
        $relative = $resolved.Substring($projectPath.Length).TrimStart("\").Replace("\", "/")
        $binding[$entry.Key] = [ordered]@{
            path = $relative
            sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    return $binding
}

function Get-ProblemLines {
    param([string]$Output)
    return @(
        $Output -split "`r?`n" |
            Where-Object { $_ -match "SCRIPT ERROR:|(^|\s)ERROR:|CRASH:" }
    )
}

function Get-LeakWarningLines {
    param([string]$Output)
    return @(
        $Output -split "`r?`n" |
            Where-Object {
                $_ -match "(?i)ObjectDB.*(?:leak|orphan)|resources still in use at exit|orphan(?:ed)? (?:node|object|instance)|RID allocations.*leaked"
            }
    )
}

function Test-MeasurementWindowState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [object]$Sample
    )

    $requiredFields = @(
        "focus_at_sample_start",
        "focus_at_sample_end",
        "focus_lost_during_sample",
        "minimized_during_sample",
        "rejected_unfocused_frames",
        "rejected_focus_recovery_frames"
    )
    $propertyNames = @($Sample.PSObject.Properties.Name)
    foreach ($field in $requiredFields) {
        if ($field -notin $propertyNames) {
            $failures.Add("$Label sample is missing required window-state evidence: $field") | Out-Null
        }
    }
    if (@($requiredFields | Where-Object { $_ -notin $propertyNames }).Count -gt 0) {
        return
    }
    if (-not [bool]$Sample.focus_at_sample_start -or -not [bool]$Sample.focus_at_sample_end) {
        $failures.Add("$Label benchmark was not focused at both sample boundaries") | Out-Null
    }
    if ([bool]$Sample.focus_lost_during_sample -or [int]$Sample.rejected_unfocused_frames -gt 0 -or [int]$Sample.rejected_focus_recovery_frames -gt 0) {
        $failures.Add("$Label benchmark lost focus during sampling; the entire sample must remain focused") | Out-Null
    }
    if ([bool]$Sample.minimized_during_sample) {
        $failures.Add("$Label benchmark was minimized during sampling") | Out-Null
    }
}

function Invoke-MapMeasurement {
    param(
        [ValidateSet("open", "twin")]
        [string]$Map
    )

    $rawReportResourcePath = "res://reports/twin_bays_splash_arena_performance_raw_$Map.json"
    $rawReportFilePath = Convert-ResourcePathToFilePath $rawReportResourcePath
    $stdoutPath = Join-Path $reportsPath "twin_bays_splash_arena_performance_$Map.stdout.log"
    $stderrPath = Join-Path $reportsPath "twin_bays_splash_arena_performance_$Map.stderr.log"
    foreach ($path in @($rawReportFilePath, $stdoutPath, $stderrPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    if ($CooldownSeconds -gt 0) {
        Write-Host "[$Map] Cooling to a matched idle state for $CooldownSeconds second(s)..."
        Start-Sleep -Seconds $CooldownSeconds
    }

    $godotArguments = @(
        "--audio-driver", "Dummy",
        "--rendering-method", "forward_plus",
        "--rendering-driver", "d3d12",
        "--disable-vsync",
        "--windowed",
        "--resolution", "960x540",
        "--path", $projectPath,
        "-s", "res://scripts/tests/twin_bays_splash_arena_performance.gd",
        "--",
        "--map=$Map",
        "--benchmark-width=$windowWidth",
        "--benchmark-height=$windowHeight",
        "--warmup=$WarmupSeconds",
        "--sample=$SampleSeconds",
        "--report=$rawReportResourcePath"
    )

    # The user-approved physical host stays decorated, non-topmost and at or
    # below 960x540. The measured GPU target remains the 1920x1080
    # UPDATE_ALWAYS SubViewport.
    $process = Start-Process `
        -FilePath $performanceGodotPath `
        -ArgumentList $godotArguments `
        -WorkingDirectory $projectPath `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Normal `
        -PassThru
    try {
        # A benchmark should not lose its 1% low evidence to background indexers
        # or WMI bursts. High is intentional but remains below Realtime, so the
        # desktop and watchdogs retain scheduling headroom.
        $process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
    } catch {
        $failures.Add("$Map benchmark priority could not be set to High: $($_.Exception.Message)") | Out-Null
    }
    $process.WaitForExit()
    $process.Refresh()
    $exitCode = [int]$process.ExitCode

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
    $problemLines = @(Get-ProblemLines $combinedOutput)
    $leakLines = @(Get-LeakWarningLines $combinedOutput)

    Write-Host "[$Map] EXIT=$exitCode"
    Write-Host "[$Map] --- STDOUT ---"
    if ($stdout) { Write-Host $stdout.TrimEnd() }
    Write-Host "[$Map] --- STDERR ---"
    if ($stderr) { Write-Host $stderr.TrimEnd() }

    $rawReport = $null
    if (Test-Path -LiteralPath $rawReportFilePath) {
        $rawReport = Get-Content -LiteralPath $rawReportFilePath -Raw | ConvertFrom-Json
    } else {
        $failures.Add("$Map benchmark did not produce $rawReportResourcePath") | Out-Null
    }
    if ($exitCode -ne 0) {
        $failures.Add("$Map benchmark exited with code $exitCode") | Out-Null
    }
    if ($problemLines.Count -gt 0) {
        $failures.Add("$Map benchmark emitted $($problemLines.Count) engine/script error line(s)") | Out-Null
    }
    if ($leakLines.Count -gt 0) {
        $failures.Add("$Map benchmark emitted shutdown leak warnings") | Out-Null
    }

    return [pscustomobject]@{
        map = $Map
        exit_code = $exitCode
        report = $rawReport
        engine_or_script_error_lines = $problemLines
        shutdown_leak_warning_lines = $leakLines
        stdout_log = "res://reports/$([IO.Path]::GetFileName($stdoutPath))"
        stderr_log = "res://reports/$([IO.Path]::GetFileName($stderrPath))"
        raw_report = $rawReportResourcePath
        process_priority = [string]$process.PriorityClass
    }
}

function Get-Ratio {
    param(
        [double]$Baseline,
        [double]$Target,
        [string]$Label
    )
    if ($Baseline -le 0.0) {
        $failures.Add("Open Ring-Out reported zero for $Label; comparison is invalid") | Out-Null
        return [double]::PositiveInfinity
    }
    return $Target / $Baseline
}

$renderMutex = Enter-RenderPerformanceGate
try {
    # Hold one global gate across both cooldowns, both samples, and both raw
    # report reads. Releasing between maps lets another benchmark steal focus
    # or remove the shared report paths before this wrapper can bind them.
    Assert-NoCompetingChaosGunGodot
    $openRun = Invoke-MapMeasurement -Map "open"
    Assert-NoCompetingChaosGunGodot
    $twinRun = Invoke-MapMeasurement -Map "twin"
} finally {
    Exit-RenderPerformanceGate -Mutex $renderMutex
}
$openSample = if ($null -ne $openRun.report) { $openRun.report.sample } else { $null }
$twinSample = if ($null -ne $twinRun.report) { $twinRun.report.sample } else { $null }

$ratios = [ordered]@{
    draw_calls = $null
    primitives = $null
    render_memory_proxy = $null
}
if ($null -eq $openSample -or $null -eq $twinSample) {
    $failures.Add("Performance samples are incomplete") | Out-Null
} else {
    $offscreenTarget = (
        [string]$openRun.report.configuration.render_target -eq "always_updating_offscreen_subviewport" `
        -and [string]$twinRun.report.configuration.render_target -eq "always_updating_offscreen_subviewport"
    )
    Test-MeasurementWindowState -Label "Open Ring-Out" -Sample $openSample
    Test-MeasurementWindowState -Label "Twin Bays" -Sample $twinSample

    if ([double]$twinSample.average_fps -lt 60.0) {
        $failures.Add(("Twin Bays average FPS {0:N2} is below 60" -f [double]$twinSample.average_fps)) | Out-Null
    }
    if ([double]$twinSample.one_percent_low_fps -lt 55.0) {
        $failures.Add(("Twin Bays 1% low {0:N2} is below 55" -f [double]$twinSample.one_percent_low_fps)) | Out-Null
    }
    if ([double]$twinSample.frame_time_p99_ms -gt 18.2) {
        $failures.Add(("Twin Bays p99 frame time {0:N2} ms exceeds 18.2 ms" -f [double]$twinSample.frame_time_p99_ms)) | Out-Null
    }
    if ([double]$twinSample.memory_drift_bytes -gt 5MB) {
        $failures.Add(("Twin Bays final-30-second memory drift {0:N2} MiB exceeds 5 MiB" -f ([double]$twinSample.memory_drift_bytes / 1MB))) | Out-Null
    }
    if ([int]$twinSample.orphan_node_delta -gt 0) {
        $failures.Add("Twin Bays unload left orphan nodes") | Out-Null
    }
    if ($openSample.render_memory_proxy_source -ne $twinSample.render_memory_proxy_source) {
        $failures.Add("Maps used different render-memory proxy sources") | Out-Null
    }

    $ratios.draw_calls = Get-Ratio `
        -Baseline ([double]$openSample.average_draw_calls) `
        -Target ([double]$twinSample.average_draw_calls) `
        -Label "draw calls"
    $ratios.primitives = Get-Ratio `
        -Baseline ([double]$openSample.average_primitives) `
        -Target ([double]$twinSample.average_primitives) `
        -Label "primitives"
    $ratios.render_memory_proxy = Get-Ratio `
        -Baseline ([double]$openSample.render_memory_proxy_bytes) `
        -Target ([double]$twinSample.render_memory_proxy_bytes) `
        -Label "render memory proxy"

    foreach ($entry in @(
        [pscustomobject]@{ Name = "draw calls"; Value = [double]$ratios.draw_calls },
        [pscustomobject]@{ Name = "primitives"; Value = [double]$ratios.primitives },
        [pscustomobject]@{ Name = "render memory proxy"; Value = [double]$ratios.render_memory_proxy }
    )) {
        if ($entry.Value -gt 1.10) {
            $failures.Add(("Twin Bays {0} ratio {1:N3} exceeds 1.10" -f $entry.Name, $entry.Value)) | Out-Null
        }
    }
}

$openConfiguration = if ($null -ne $openRun.report) { $openRun.report.configuration } else { $null }
$twinConfiguration = if ($null -ne $twinRun.report) { $twinRun.report.configuration } else { $null }
if ($null -eq $openConfiguration -or $null -eq $twinConfiguration) {
    $failures.Add("Performance environment metadata is incomplete") | Out-Null
} else {
    foreach ($field in @(
        "engine_version",
        "rendering_method",
        "rendering_driver",
        "video_adapter",
        "display_driver",
        "resolution",
        "window_size",
        "viewport_size",
        "host_window_size",
        "render_target",
        "borderless",
        "no_focus",
        "always_on_top",
        "vsync_mode",
        "engine_max_fps",
        "low_processor_usage_mode"
    )) {
        $openValue = $openConfiguration.$field | ConvertTo-Json -Compress -Depth 10
        $twinValue = $twinConfiguration.$field | ConvertTo-Json -Compress -Depth 10
        if ($openValue -ne $twinValue) {
            $failures.Add("Open Ring-Out and Twin Bays used different $field values") | Out-Null
        }
    }
    if ([string]$twinConfiguration.rendering_driver -ne "d3d12") {
        $failures.Add("Windows production performance gate requires D3D12 Forward+; reported driver was $($twinConfiguration.rendering_driver)") | Out-Null
    }
    $requiredResolution = @(1920, 1080) | ConvertTo-Json -Compress
    if (($twinConfiguration.resolution | ConvertTo-Json -Compress) -ne $requiredResolution `
        -or ($twinConfiguration.viewport_size | ConvertTo-Json -Compress) -ne $requiredResolution) {
        $failures.Add("Production performance gate requires a true 1920x1080 render target and viewport") | Out-Null
    }
    if ([string]$twinConfiguration.render_target -ne "always_updating_offscreen_subviewport") {
        $failures.Add("Production performance gate requires the always-updating offscreen render target") | Out-Null
    }
    $hostSize = @($twinConfiguration.host_window_size)
    if ($hostSize.Count -ne 2 -or [int]$hostSize[0] -gt 960 -or [int]$hostSize[1] -gt 540) {
        $failures.Add("Offscreen performance host window must not exceed 960x540") | Out-Null
    }
}

$finalReport = [ordered]@{
    schema_version = 1
    mode = "separate_process_comparison"
    artifact_binding = Get-PerformanceArtifactBinding
    configuration = [ordered]@{
        launcher_path = $performanceGodotPath
        launcher_sha256 = $performanceLauncherSha256
        engine_version = if ($null -ne $twinConfiguration) { $twinConfiguration.engine_version } else { $null }
        rendering_method = if ($null -ne $twinConfiguration) { $twinConfiguration.rendering_method } else { $null }
        rendering_driver = if ($null -ne $twinConfiguration) { $twinConfiguration.rendering_driver } else { $null }
        video_adapter = if ($null -ne $twinConfiguration) { $twinConfiguration.video_adapter } else { $null }
        display_driver = if ($null -ne $twinConfiguration) { $twinConfiguration.display_driver } else { $null }
        resolution = if ($null -ne $twinConfiguration) { $twinConfiguration.resolution } else { @(1920, 1080) }
        window_size = if ($null -ne $twinConfiguration) { $twinConfiguration.window_size } else { $null }
        viewport_size = if ($null -ne $twinConfiguration) { $twinConfiguration.viewport_size } else { $null }
        host_window_size = if ($null -ne $twinConfiguration) { $twinConfiguration.host_window_size } else { $null }
        render_target = if ($null -ne $twinConfiguration) { $twinConfiguration.render_target } else { $null }
        always_on_top = if ($null -ne $twinConfiguration) { $twinConfiguration.always_on_top } else { $null }
        borderless = if ($null -ne $twinConfiguration) { $twinConfiguration.borderless } else { $null }
        vsync_mode = if ($null -ne $twinConfiguration) { $twinConfiguration.vsync_mode } else { $null }
        engine_max_fps = if ($null -ne $twinConfiguration) { $twinConfiguration.engine_max_fps } else { $null }
        low_processor_usage_mode = if ($null -ne $twinConfiguration) { $twinConfiguration.low_processor_usage_mode } else { $null }
        slots = "1 human + 3 AI"
        warmup_seconds = $WarmupSeconds
        sample_seconds = $SampleSeconds
        matched_idle_cooldown_seconds_before_each_map = $CooldownSeconds
        thresholds = [ordered]@{
            minimum_average_fps = 60.0
            minimum_one_percent_low_fps = 55.0
            maximum_p99_frame_time_ms = 18.2
            maximum_relative_render_cost = 1.10
            maximum_final_30_second_memory_drift_bytes = 5MB
        }
        visible_window_approval = [ordered]@{
            approved = [bool]$VisibleWindowApproved
            reason = $VisibleWindowApprovalReason
        }
        baseline_update = "not applicable; this is a live paired comparison and writes no golden baseline"
    }
    open_ringout = $openSample
    twin_bays = $twinSample
    ratios = $ratios
    process_validation = [ordered]@{
        open_ringout = [ordered]@{
            exit_code = $openRun.exit_code
            engine_or_script_error_lines = $openRun.engine_or_script_error_lines
            shutdown_leak_warning_lines = $openRun.shutdown_leak_warning_lines
            stdout_log = $openRun.stdout_log
            stderr_log = $openRun.stderr_log
            raw_report = $openRun.raw_report
        }
        twin_bays = [ordered]@{
            exit_code = $twinRun.exit_code
            engine_or_script_error_lines = $twinRun.engine_or_script_error_lines
            shutdown_leak_warning_lines = $twinRun.shutdown_leak_warning_lines
            stdout_log = $twinRun.stdout_log
            stderr_log = $twinRun.stderr_log
            raw_report = $twinRun.raw_report
        }
    }
    failures = @($failures)
    passed = ($failures.Count -eq 0)
    generated_at_unix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

$finalReportFilePath = Convert-ResourcePathToFilePath $ReportPath
$finalReportDirectory = Split-Path -Parent $finalReportFilePath
if (-not (Test-Path -LiteralPath $finalReportDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $finalReportDirectory -Force | Out-Null
}
$finalReport | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $finalReportFilePath -Encoding utf8

Write-Output "--- PERFORMANCE SUMMARY ---"
if ($null -ne $twinSample) {
    Write-Output ("Twin avg FPS: {0:N2}" -f [double]$twinSample.average_fps)
    Write-Output ("Twin 1% low: {0:N2}" -f [double]$twinSample.one_percent_low_fps)
    Write-Output ("Draw-call ratio: {0:N3}" -f [double]$ratios.draw_calls)
    Write-Output ("Primitive ratio: {0:N3}" -f [double]$ratios.primitives)
    Write-Output ("Render-memory ratio: {0:N3}" -f [double]$ratios.render_memory_proxy)
}
Write-Output "Performance report: $finalReportFilePath"

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure -ErrorAction Continue
    }
    throw "Twin Bays performance gate failed with $($failures.Count) issue(s)."
}
