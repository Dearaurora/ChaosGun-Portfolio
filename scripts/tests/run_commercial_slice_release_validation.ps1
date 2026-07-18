[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$reportsPath = Join-Path $projectPath "reports"
$runId = "$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))-pid$PID"
$runPath = Join-Path $reportsPath "commercial_slice_release_validation\$runId"
$reportPath = Join-Path $reportsPath "commercial_slice_release_validation.json"
$logPath = Join-Path $runPath "run.log"

$gates = [System.Collections.Generic.List[object]]::new()
$hashes = [ordered]@{}
$failure = $null
$commit = "unknown"
$godotVersion = "unknown"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

New-Item -ItemType Directory -Path $runPath -Force | Out-Null
New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null
Set-Content -LiteralPath $logPath -Value @(
    "Open Ring-Out P29-P31 commercial slice release validation",
    "Started: $([DateTime]::UtcNow.ToString('o'))",
    "RunId: $runId",
    "Project: $projectPath",
    "Godot: $GodotPath",
    "Headless: true",
    "GUI/performance execution: false",
    ""
)

function Write-RunLog {
    param([string[]]$Lines)
    Add-Content -LiteralPath $logPath -Value $Lines
}

function Get-Commit {
    $value = & git -C $projectPath rev-parse HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($value | Out-String))) {
        return ([string]($value | Select-Object -First 1)).Trim()
    }
    return "unknown"
}

function Get-HashBinding {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    $fullPath = Join-Path $projectPath $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required release binding is missing: $RelativePath"
    }
    $hashes[$Name] = [ordered]@{
        path = $RelativePath.Replace("\", "/")
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Get-OutputDiagnostics {
    param([Parameter(Mandatory = $true)][string]$Output)
    @(
        $Output -split "`r?`n" |
            Where-Object {
                $_ -match '(?i)SCRIPT ERROR' -or
                $_ -match '(?i)\bERROR\b' -or
                $_ -match '(?i)\bCRASH\b' -or
                $_ -match '(?i)ObjectDB.*(?:leak|orphan)' -or
                $_ -match '(?i)resources still in use at exit' -or
                $_ -match '(?i)orphan(?:ed)? (?:node|object|instance)' -or
                $_ -match '(?i)RID allocations.*leaked'
            }
    )
}

function Invoke-GodotGate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $slug = ($Name -replace '[^A-Za-z0-9_-]', '_').ToLowerInvariant()
    $stdoutPath = Join-Path $runPath "$slug.stdout.txt"
    $stderrPath = Join-Path $runPath "$slug.stderr.txt"
    $started = [DateTime]::UtcNow
    $exitCode = -1
    $stdout = ""
    $stderr = ""
    $diagnostics = @()

    try {
        $process = Start-Process -FilePath $GodotPath `
            -ArgumentList $Arguments `
            -WorkingDirectory $projectPath `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -NoNewWindow `
            -PassThru `
            -Wait
        $exitCode = $process.ExitCode
        if (Test-Path -LiteralPath $stdoutPath) {
            $stdout = [string](Get-Content -LiteralPath $stdoutPath -Raw)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $stderr = [string](Get-Content -LiteralPath $stderrPath -Raw)
        }
        $diagnostics = @(Get-OutputDiagnostics -Output "$stdout`n$stderr")
    } catch {
        $diagnostics = @($_.Exception.Message)
        $stderr = $_.Exception.ToString()
    }

    $passed = ($exitCode -eq 0 -and $diagnostics.Count -eq 0)
    $result = [ordered]@{
        name = $Name
        passed = $passed
        exit_code = $exitCode
        duration_seconds = [Math]::Round(([DateTime]::UtcNow - $started).TotalSeconds, 3)
        stdout_log = $stdoutPath
        stderr_log = $stderrPath
        diagnostics = @($diagnostics)
    }
    $gates.Add($result)
    Write-RunLog @(
        "==================================================",
        "[$Name] passed=$passed exit=$exitCode",
        "Arguments: $($Arguments -join ' ')",
        "Diagnostics: $($diagnostics.Count)",
        ""
    )
    if (-not $passed) {
        throw "Commercial slice gate failed: $Name"
    }
}

function Write-CanonicalReport {
    param([Parameter(Mandatory = $true)][bool]$Passed)
    $report = [ordered]@{
        run_id = $runId
        commit = $commit
        godot_version = $godotVersion
        passed = $Passed
        release_complete = $false
        static_preflight = $true
        gui_run = $false
        performance_run = $false
        gates = @($gates)
        hashes = $hashes
        run_log = $logPath
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding UTF8
}

$commit = Get-Commit

try {
    $versionOutput = & $GodotPath --version 2>&1 | Out-String
    $godotVersion = $versionOutput.Trim()

    Get-HashBinding -Name "hero_glb" -RelativePath "assets/models/generated/characters/hero_character_rig_v2.glb"
    Get-HashBinding -Name "hero_blend" -RelativePath "assets/source/characters/hero_character_rig_v2.blend"
    Get-HashBinding -Name "p29_builder" -RelativePath "tools/build_hero_character_rig_v2.py"
    Get-HashBinding -Name "p29_geometry" -RelativePath "tools/hero_character_p29_geometry.py"
    Get-HashBinding -Name "ai_character" -RelativePath "scripts/player/ai_character.gd"
    Get-HashBinding -Name "projectile" -RelativePath "scripts/weapons/projectile.gd"
    Get-HashBinding -Name "open_ringout_slice" -RelativePath "scripts/maps/open_ringout_slice.gd"
    Get-HashBinding -Name "ringout_hud" -RelativePath "scripts/ui/ringout_hud.gd"

    $headlessArgs = @("--headless", "--editor", "--path", $projectPath, "--quit")
    Invoke-GodotGate -Name "clean_headless_import" -Arguments $headlessArgs

    $scriptArgs = @("--headless", "--path", $projectPath, "--audio-driver", "Dummy", "--display-driver", "headless", "--rendering-method", "gl_compatibility", "--script")
    $gateScripts = @(
        @{ Name = "hero_character_rig_asset"; Script = "res://scripts/tests/hero_character_rig_asset_verifier.gd" },
        @{ Name = "authored_character_motion"; Script = "res://scripts/tests/authored_character_motion_verifier.gd" },
        @{ Name = "character_locomotion_visual"; Script = "res://scripts/tests/character_locomotion_visual_verifier.gd" },
        @{ Name = "character_weapon_readability"; Script = "res://scripts/tests/character_weapon_readability_verifier.gd" },
        @{ Name = "character_combat_feedback"; Script = "res://scripts/tests/character_combat_feedback_verifier.gd" },
        @{ Name = "ai_point_blank_fire"; Script = "res://scripts/tests/ai_point_blank_fire_verifier.gd" },
        @{ Name = "ai_point_blank_hit"; Script = "res://scripts/tests/ai_point_blank_hit_verifier.gd" },
        @{ Name = "open_ringout_slice"; Script = "res://scripts/tests/open_ringout_slice_verifier.gd" },
        @{ Name = "open_ringout_camera"; Script = "res://scripts/tests/open_ringout_camera_verifier.gd" },
        @{ Name = "open_ringout_match_presentation"; Script = "res://scripts/tests/open_ringout_match_presentation_verifier.gd" },
        @{ Name = "p28_ui_system"; Script = "res://scripts/tests/p28_ui_system_verifier.gd" },
        @{ Name = "open_ringout_render_cost"; Script = "res://scripts/tests/open_ringout_render_cost_verifier.gd" }
    )
    foreach ($gate in $gateScripts) {
        Invoke-GodotGate -Name $gate.Name -Arguments ($scriptArgs + $gate.Script)
    }

    Write-CanonicalReport -Passed $true
    Write-RunLog @("Completed: $([DateTime]::UtcNow.ToString('o'))", "Result: PASS", "")
} catch {
    $failure = $_.Exception.Message
    Write-RunLog @("Completed: $([DateTime]::UtcNow.ToString('o'))", "Result: FAIL", "Failure: $failure", "")
    Write-CanonicalReport -Passed $false
    throw
}
