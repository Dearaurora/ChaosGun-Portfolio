[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [switch]$DevOnly,

    [switch]$Quick,

    [switch]$SkipPerformance,

    [string]$PerformanceEvidencePath = ""
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

if (-not ("ChaosGunPerformanceWindow" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class ChaosGunPerformanceWindow
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@
}

function Restore-PerformanceWindow {
    param([System.Diagnostics.Process]$Process)
    $deadline = [DateTime]::UtcNow.AddSeconds(12)
    while ([DateTime]::UtcNow -lt $deadline -and -not $Process.HasExited) {
        $Process.Refresh()
        $handle = $Process.MainWindowHandle
        if ($handle -ne [IntPtr]::Zero) {
            [void][ChaosGunPerformanceWindow]::ShowWindowAsync($handle, 9)
            [void][ChaosGunPerformanceWindow]::SetForegroundWindow($handle)
            return
        }
        Start-Sleep -Milliseconds 100
    }
}

$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$projectPath = (Resolve-Path -LiteralPath $projectPath).Path
$reportsPath = Join-Path $projectPath "reports"
$runId = "$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))-pid$PID"
$workPath = Join-Path $reportsPath "momentum_circuit_release_validation\$runId"
$masterLog = Join-Path $reportsPath "momentum_circuit_release_validation.log"
$releaseReportPath = Join-Path $reportsPath "momentum_circuit_release_validation.json"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

New-Item -ItemType Directory -Path $workPath -Force | Out-Null
Set-Content -LiteralPath $masterLog -Value @(
    "Momentum Circuit release validation",
    "Started: $([DateTime]::UtcNow.ToString('o'))",
    "RunId: $runId",
    "Project: $projectPath",
    "Godot: $GodotPath",
    "DevOnly: $DevOnly",
    "Quick: $Quick",
    "SkipPerformance: $SkipPerformance",
    "PerformanceEvidencePath: $PerformanceEvidencePath",
    "StageLogs: $workPath",
    ""
)

function Invoke-CheckedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$VisibleWindow
    )

    $stem = ($Label -replace '[^A-Za-z0-9_-]', '_').ToLowerInvariant()
    $stdoutPath = Join-Path $workPath "$stem.stdout.txt"
    $stderrPath = Join-Path $workPath "$stem.stderr.txt"
    foreach ($path in @($stdoutPath, $stderrPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    # On Windows the console launcher can return before its GUI sibling has
    # flushed redirected output. Wait on the real engine process instead.
    $executionPath = $FilePath
    # Wait on the real engine process. Rendered stages also need its native
    # window handle so a minimized inherited state can be restored explicitly.
    if ($executionPath.EndsWith("_console.exe", [StringComparison]::OrdinalIgnoreCase)) {
        $candidate = $executionPath.Substring(
            0,
            $executionPath.Length - "_console.exe".Length
        ) + ".exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $executionPath = $candidate
        }
    }

    Write-Host "[$Label]"
    $startParameters = @{
        FilePath = $executionPath
        ArgumentList = $Arguments
        WorkingDirectory = $projectPath
        RedirectStandardOutput = $stdoutPath
        RedirectStandardError = $stderrPath
        PassThru = $true
    }
    if ($VisibleWindow) {
        # A real, normally restored window is part of the performance evidence.
        # -NoNewWindow can inherit a minimized show state from the host process,
        # invalidating Forward+ frame-time sampling even though rendering runs.
        $startParameters.WindowStyle = "Normal"
    } else {
        $startParameters.NoNewWindow = $true
        $startParameters.Wait = $true
    }
    $renderMutex = $null
    try {
        if ($VisibleWindow) {
            $renderMutex = Enter-RenderPerformanceGate
        }
        $process = Start-Process @startParameters
        if ($VisibleWindow) {
            Restore-PerformanceWindow -Process $process
            $process.WaitForExit()
            $process.Refresh()
        }
    } finally {
        if ($null -ne $renderMutex) {
            Exit-RenderPerformanceGate -Mutex $renderMutex
        }
    }

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
    $combined = "$stdout`n$stderr"
    $exitCode = $process.ExitCode
    if ($VisibleWindow -and $null -eq $exitCode) {
        # Start-Process can lose ExitCode for a Windows GUI executable even
        # after WaitForExit. Only accept that case when the benchmark emitted
        # its explicit success marker; a native crash never reaches it.
        $exitCode = if ($combined -match 'RESULT momentum_circuit_performance passed=true') { 0 } else { -1 }
    }
    Add-Content -LiteralPath $masterLog -Value @(
        "==================================================",
        "[$Label] EXIT=$exitCode",
        "--- STDOUT ---",
        $stdout.TrimEnd(),
        "--- STDERR ---",
        $stderr.TrimEnd(),
        ""
    )
    if ($stdout) { Write-Host $stdout.TrimEnd() }
    if ($stderr) { Write-Host $stderr.TrimEnd() }

    $fatalLines = @(
        $combined -split "`r?`n" |
            Where-Object {
                $_ -match '(?i)SCRIPT ERROR:|Parse Error|(^|\s)ERROR:|CRASH:' -or
                $_ -match '(?i)(?:resource|scene|script).*(?:missing|not found|failed to load|could not load)' -or
                $_ -match '(?i)(?:failed loading resource|could not load resource|resource file not found|no loader found|cannot open file)' -or
                $_ -match '(?i)ObjectDB.*(?:leak|orphan)|ObjectDB instances leaked at exit' -or
                $_ -match '(?i)resources still in use at exit|RID allocations.*leaked' -or
                $_ -match '(?i)orphan(?:ed)? (?:node|object|instance)'
            }
    )
    if ($exitCode -ne 0) {
        throw "$Label exited with code $exitCode. See $masterLog"
    }
    if ($fatalLines.Count -gt 0) {
        throw "$Label emitted a parse/script/engine/leak error. See $masterLog"
    }
}

function Invoke-GodotScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [switch]$Rendered,

		[switch]$AcceleratedHeadless,

        [string[]]$UserArguments = @()
    )

    $arguments = @()
    if ($Rendered) {
        $arguments += @(
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--disable-vsync",
            "--windowed",
            "--resolution", "960x540"
        )
    } else {
        $arguments += @("--headless", "--audio-driver", "Dummy")
		if ($AcceleratedHeadless) {
			# The AI gate counts authoritative physics frames, not wall time.
			# Fixed FPS at the project's authoritative 60 Hz disables wall-time
			# sleeping without changing the number or delta of physics steps.
			$arguments += @("--fixed-fps", "60")
		}
    }
    $arguments += @("--path", $projectPath, "--script", $ScriptPath)
    if ($UserArguments.Count -gt 0) {
        $arguments += "--"
        $arguments += $UserArguments
    }
    Invoke-CheckedProcess `
        -Label $Label `
        -FilePath $GodotPath `
        -Arguments $arguments `
        -VisibleWindow:$Rendered
}

function Get-ReportSummary {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $report = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    return [ordered]@{
        path = "res://$($Path.Substring($projectPath.Length + 1).Replace('\', '/'))"
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        passed = [bool]$report.passed
    }
}

function Invoke-IsolatedAIBatch {
    param([switch]$QuickMode)

    $seeds = if ($QuickMode) { @(101) } else { @(101, 211, 307, 401, 503, 601, 701, 809) }
    $durationSeconds = if ($QuickMode) { 3 } else { 30 }
    $seedReports = @()
    foreach ($seed in $seeds) {
        $relativeReport = "res://reports/momentum_circuit_ai_seed_$seed.json"
        $absoluteReport = Join-Path $reportsPath "momentum_circuit_ai_seed_$seed.json"
        if (Test-Path -LiteralPath $absoluteReport) {
            Remove-Item -LiteralPath $absoluteReport -Force
        }
        Invoke-GodotScript `
            -Label "Momentum Circuit AI seed $seed" `
            -ScriptPath "res://scripts/tests/momentum_circuit_ai_batch.gd" `
            -AcceleratedHeadless `
            -UserArguments @(
                "--rounds=1",
                "--duration=$durationSeconds",
                "--seed=$seed",
                "--report=$relativeReport"
            )
        if (-not (Test-Path -LiteralPath $absoluteReport -PathType Leaf)) {
            throw "AI seed $seed did not produce its report: $absoluteReport"
        }
        $report = Get-Content -LiteralPath $absoluteReport -Raw | ConvertFrom-Json
        if (-not [bool]$report.passed) {
            throw "AI seed $seed failed its report contract. See $absoluteReport"
        }
        if ([int]$report.configuration.duration_seconds -ne $durationSeconds) {
            throw "AI seed $seed reported the wrong duration. See $absoluteReport"
        }
        if (@($report.results).Count -ne 1 -or [int]$report.results[0].seed -ne $seed) {
            throw "AI seed $seed report identity is invalid. See $absoluteReport"
        }
        $seedReports += $report
    }

    $results = @($seedReports | ForEach-Object { @($_.results) })
    $dangerVerified = @($seedReports | Where-Object { -not [bool]$_.aggregate.danger_bias.verified }).Count -eq 0
    if (-not $dangerVerified) {
        throw "At least one isolated AI seed failed the warning-bridge escape-bias probe."
    }
    $combinedReport = [ordered]@{
        schema_version = 1
        scene = "res://scenes/maps/momentum_circuit_arena.tscn"
        configuration = [ordered]@{
            seeds = $seeds
            duration_seconds = $durationSeconds
            permanent_fall_seconds = 4.0
            abnormal_wipe_seconds = 2.0
            release_gate = -not [bool]$QuickMode
            process_isolation = "one_clean_godot_process_per_seed"
        }
        results = $results
        aggregate = [ordered]@{
            rounds = $results.Count
            total_deaths = [int](($results | Measure-Object -Property total_deaths -Sum).Sum)
            total_kills = [int](($results | Measure-Object -Property total_kills -Sum).Sum)
            bridge_switch_rounds = @($results | Where-Object { [int]$_.bridge_switch_serial -gt 0 }).Count
            danger_bias = $seedReports[0].aggregate.danger_bias
        }
        failures = @()
        passed = $true
        generated_at_unix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }
    $combinedReport | ConvertTo-Json -Depth 20 | Set-Content `
        -LiteralPath (Join-Path $reportsPath "momentum_circuit_ai_batch.json") `
        -Encoding utf8
}

$stageResults = [ordered]@{}

try {
    Invoke-CheckedProcess `
        -Label "Godot import" `
        -FilePath $GodotPath `
        -Arguments @(
            "--headless", "--audio-driver", "Dummy", "--editor",
            "--path", $projectPath, "--import", "--quit"
        )
    $stageResults.import = "passed"

    Write-Host "`n=== Frozen whitebox regression ==="
    Invoke-GodotScript `
        -Label "Momentum Circuit whitebox regression" `
        -ScriptPath "res://scripts/tests/momentum_circuit_whitebox_verifier.gd"
    $stageResults.whitebox = "passed"

    Write-Host "`n=== Production structure and visual contract ==="
    Invoke-GodotScript `
        -Label "Momentum Circuit production contract" `
        -ScriptPath "res://scripts/tests/momentum_circuit_production_verifier.gd" `
        -UserArguments @("--require-map-pool=false")
    $stageResults.production = "passed"

    Write-Host "`n=== v9 environment asset and motion contract ==="
    Invoke-GodotScript `
        -Label "Momentum Circuit v9 environment" `
        -ScriptPath "res://scripts/tests/momentum_circuit_environment_v9_verifier.gd"
    $stageResults.environment_v9 = "ten-families-three-motion-systems-pass"

    Write-Host "`n=== Rotating light bridges and random teleport mechanics ==="
    Invoke-GodotScript `
        -Label "Momentum Circuit rotating light bridge mechanics" `
        -ScriptPath "res://scripts/tests/momentum_circuit_light_bridge_mechanics_verifier.gd"
    $stageResults.mechanics = "passed"

    Write-Host "`n=== Random teleporter landing-pad cooldown ==="
    Invoke-GodotScript `
        -Label "Momentum Circuit teleporter cooldown" `
        -ScriptPath "res://scripts/tests/momentum_circuit_teleporter_cooldown_verifier.gd"
    $stageResults.teleporter_cooldown = "3-second-pass"

    Write-Host "`n=== Projectile readability on dark deck ==="
    Invoke-GodotScript `
        -Label "Momentum Circuit projectile readability" `
        -ScriptPath "res://scripts/tests/momentum_circuit_projectile_readability_verifier.gd"
    $stageResults.projectile_readability = "six-weapons-pass"

    Write-Host "`n=== Shared match runtime flow ==="
    Invoke-GodotScript `
        -Label "Momentum Circuit runtime flow" `
        -ScriptPath "res://scripts/tests/momentum_circuit_runtime_verifier.gd"
    $stageResults.runtime = "passed"

    Write-Host "`n=== Shared AI point-blank fire regression ==="
    Invoke-GodotScript `
        -Label "AI point-blank fire" `
        -ScriptPath "res://scripts/tests/ai_point_blank_fire_verifier.gd"
    $stageResults.ai_point_blank = "passed"

    Write-Host "`n=== Fixed-seed AI integrity batch ==="
    Invoke-IsolatedAIBatch -QuickMode:$Quick
    $stageResults.ai = if ($Quick) { "quick-pass" } else { "8x30-pass" }

    if ($SkipPerformance) {
        Write-Host "`n=== Performance explicitly skipped ==="
        $stageResults.performance = "skipped"
    } elseif ($PerformanceEvidencePath) {
        $resolvedEvidence = (Resolve-Path -LiteralPath $PerformanceEvidencePath).Path
        if (-not $resolvedEvidence.StartsWith($reportsPath, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Performance evidence must be under $reportsPath"
        }
        $relativeEvidence = $resolvedEvidence.Substring($projectPath.Length).TrimStart('\').Replace('\', '/')
        Write-Host "`n=== Revalidate existing 60-second Forward+ evidence ==="
        Invoke-GodotScript `
            -Label "Momentum Circuit Forward+ evidence" `
            -ScriptPath "res://scripts/tests/momentum_circuit_performance_evidence_verifier.gd" `
            -UserArguments @("--input=res://$relativeEvidence")
        $stageResults.performance = "60-second-evidence-pass"
    } else {
        Write-Host "`n=== Forward+ 1920x1080 performance ==="
        $performanceArguments = @("--map=compare")
        if ($Quick) {
            $performanceArguments += @("--warmup=1", "--sample=3")
        }
        Invoke-GodotScript `
            -Label "Momentum Circuit Forward+ performance" `
            -ScriptPath "res://scripts/tests/momentum_circuit_performance.gd" `
            -Rendered `
            -UserArguments $performanceArguments
        $stageResults.performance = if ($Quick) { "quick-pass" } else { "60-second-pass" }
    }

    # Map-pool exposure is deliberately last. The DevOnly path proves every
    # implementation contract without requiring premature player exposure.
    if ($DevOnly) {
        Write-Host "`n=== Map pool release check skipped by -DevOnly ==="
        $stageResults.map_pool = "dev-only-skipped"
    } else {
        Write-Host "`n=== Final player-facing map pool gate ==="
        Invoke-GodotScript `
            -Label "Momentum Circuit map index 2" `
            -ScriptPath "res://scripts/tests/momentum_circuit_production_verifier.gd" `
            -UserArguments @("--require-map-pool=true")
        $stageResults.map_pool = "passed-index-2"

        Write-Host "`n=== Player-facing selector and rematch routes ==="
        Invoke-GodotScript `
            -Label "Three-map player entry routes" `
            -ScriptPath "res://scripts/tests/playable_match_routes_open_ringout_verifier.gd"
        $stageResults.player_routes = "three-map-entry-pass"
    }

    $releaseComplete = -not $DevOnly -and -not $Quick -and -not $SkipPerformance
    $resultLabel = if ($releaseComplete) {
        "RELEASE PASS"
    } else {
        "DEVELOPMENT PASS (explicit gates skipped or shortened)"
    }
    $performanceReportPath = if ($PerformanceEvidencePath) {
        (Resolve-Path -LiteralPath $PerformanceEvidencePath).Path
    } else {
        Join-Path $reportsPath "momentum_circuit_performance.json"
    }
    $performanceSummary = Get-ReportSummary -Path $performanceReportPath
    if ($PerformanceEvidencePath -and $null -ne $performanceSummary) {
        # The raw report may have been rejected by an older diagnostic-only
        # memory-high-water rule. The dedicated verifier above recomputes the
        # current release gates from the immutable raw metrics.
        $performanceSummary.passed = $true
        $performanceSummary.revalidated = $true
        $performanceSummary.verifier = "res://scripts/tests/momentum_circuit_performance_evidence_verifier.gd"
    }
    $evidence = [ordered]@{
        schema_version = 1
        run_id = $runId
        result = $resultLabel
        release_complete = $releaseComplete
        dev_only = [bool]$DevOnly
        quick = [bool]$Quick
        skip_performance = [bool]$SkipPerformance
        stages = $stageResults
        ai_report = Get-ReportSummary -Path (Join-Path $reportsPath "momentum_circuit_ai_batch.json")
        performance_report = $performanceSummary
        generated_at_utc = [DateTime]::UtcNow.ToString('o')
    }
    $evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $releaseReportPath -Encoding utf8
    Add-Content -LiteralPath $masterLog -Value @(
        "",
        "Completed: $([DateTime]::UtcNow.ToString('o'))",
        "Evidence: $releaseReportPath",
        "RESULT: $resultLabel"
    )
    Write-Host "`nMomentum Circuit validation $resultLabel"
    Write-Host "Log: $masterLog"
} catch {
    $failureMessage = $_.Exception.Message
    Add-Content -LiteralPath $masterLog -Value @(
        "",
        "Completed: $([DateTime]::UtcNow.ToString('o'))",
        "RESULT: RELEASE FAIL",
        "ERROR: $failureMessage"
    )
    Write-Host "`nMomentum Circuit validation RELEASE FAIL"
    Write-Host "Log: $masterLog"
    throw
}
