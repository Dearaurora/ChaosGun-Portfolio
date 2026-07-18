[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$BlenderPath = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",

    [switch]$RebuildAssets,

    [switch]$Quick,

    [switch]$SkipRender,

    [Alias("update-baseline")]
    [switch]$UpdateBaseline,

    [switch]$ReleaseCandidate,

    [string]$ReleaseReason = "",

    [switch]$OverrideRetryLimit,

    [string]$OverrideReason = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$projectPath = (Resolve-Path -LiteralPath $projectPath).Path
$reportsPath = Join-Path $projectPath "reports"
$runId = "$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))-pid$PID"
$workRoot = Join-Path $reportsPath "twin_bays_release_validation"
$workPath = Join-Path $workRoot $runId
$masterLog = Join-Path $reportsPath "twin_bays_release_validation.log"
$releaseReportPath = Join-Path $reportsPath "twin_bays_release_validation.json"
$baselinePath = Join-Path $reportsPath "baselines\twin_bays_splash_arena"
$layoutPath = Join-Path $projectPath "resources\maps\twin_bays_layout_v1.json"
$manifestPath = Join-Path $projectPath "assets\models\generated\twin_bays_splash_arena\twin_bays_splash_arena_manifest.json"
$referenceManifestPath = Join-Path $projectPath "docs\art-direction\references\twin_bays\twin_bays_as_built_reference_v1.json"
$verificationPolicyPath = Join-Path $projectPath "resources\validation\twin_bays_verification_policy_v1.json"
$attemptLedgerPath = Join-Path $reportsPath "twin_bays_release_attempts.json"
$captureHashes = [ordered]@{}
$aiReportBinding = $null
$performanceReportBinding = $null

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}
if ($UpdateBaseline -and $SkipRender) {
    throw "--update-baseline / -UpdateBaseline cannot be combined with -SkipRender because no captures would be produced."
}
if ($UpdateBaseline -and $Quick) {
    throw "--update-baseline / -UpdateBaseline requires the complete non-Quick release validation."
}
$isFullGateRequest = -not $Quick -and -not $SkipRender
if ($isFullGateRequest -and -not $ReleaseCandidate) {
    throw "A complete runner is release-only. Pass -ReleaseCandidate and -ReleaseReason; use -Quick or a targeted gate while developing."
}
if ($isFullGateRequest -and [string]::IsNullOrWhiteSpace($ReleaseReason)) {
    throw "A complete runner requires a non-empty -ReleaseReason so its cost and purpose are explicit."
}
if ($OverrideRetryLimit -and [string]::IsNullOrWhiteSpace($OverrideReason)) {
    throw "-OverrideRetryLimit requires a non-empty -OverrideReason."
}
if (-not (Test-Path -LiteralPath $verificationPolicyPath -PathType Leaf)) {
    throw "Twin Bays verification policy is missing: $verificationPolicyPath"
}
$verificationPolicy = Get-Content -LiteralPath $verificationPolicyPath -Raw | ConvertFrom-Json
$maximumConsecutiveFailedAttempts = [int]$verificationPolicy.expensive_gates.full_release.maximum_consecutive_failed_attempts_per_fingerprint
if ($maximumConsecutiveFailedAttempts -lt 1) {
    throw "Twin Bays verification policy contains an invalid retry limit."
}

New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null
New-Item -ItemType Directory -Path $workPath -Force | Out-Null
# The top-level JSON is the canonical "latest run" pointer. Remove it before
# doing any work so a failed invocation can never leave an older PASS looking
# like evidence for the current assets or runner revision. Per-run logs remain
# preserved under $workPath for diagnosis.
if (Test-Path -LiteralPath $releaseReportPath -PathType Leaf) {
    Remove-Item -LiteralPath $releaseReportPath -Force
}
Set-Content -LiteralPath $masterLog -Value @(
    "Twin Bays Splash Arena release validation",
    "Started: $([DateTime]::UtcNow.ToString('o'))",
    "RunId: $runId",
    "StageLogs: $workPath",
    "Project: $projectPath",
    "Godot: $GodotPath",
    "Quick: $Quick",
    "SkipRender: $SkipRender",
    "UpdateBaseline: $UpdateBaseline",
    "ReleaseCandidate: $ReleaseCandidate",
    "ReleaseReason: $ReleaseReason",
    "OverrideRetryLimit: $OverrideRetryLimit",
    "OverrideReason: $OverrideReason",
    ""
)

function Invoke-CheckedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $stem = ($Label -replace '[^A-Za-z0-9_-]', '_').ToLowerInvariant()
    $stdoutPath = Join-Path $workPath "$stem.stdout.txt"
    $stderrPath = Join-Path $workPath "$stem.stderr.txt"
    foreach ($path in @($stdoutPath, $stderrPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    Write-Host "[$Label]"
    $executionPath = $FilePath
    if ($FilePath.EndsWith("_console.exe", [StringComparison]::OrdinalIgnoreCase)) {
        $candidate = $FilePath.Substring(0, $FilePath.Length - "_console.exe".Length) + ".exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            # The console launcher can return before its GUI sibling has flushed
            # redirected output under Windows PowerShell 5.1. Wait on the real
            # engine process so result logs and exit codes are authoritative.
            $executionPath = $candidate
        }
    }
    $process = Start-Process `
        -FilePath $executionPath `
        -ArgumentList $Arguments `
        -WorkingDirectory $projectPath `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -NoNewWindow `
        -PassThru `
        -Wait
    $exitCode = $process.ExitCode

    $stdout = ""
    $stderr = ""
    if (Test-Path -LiteralPath $stdoutPath) {
        $stdoutContent = Get-Content -LiteralPath $stdoutPath -Raw
        if ($null -ne $stdoutContent) { $stdout = [string]$stdoutContent }
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $stderrContent = Get-Content -LiteralPath $stderrPath -Raw
        if ($null -ne $stderrContent) { $stderr = [string]$stderrContent }
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
    if ($stdout) {
        Write-Host $stdout.TrimEnd()
    }
    if ($stderr) {
        Write-Host $stderr.TrimEnd()
    }
    $combinedOutput = "$stdout`n$stderr"
    $engineErrorLines = @(
        $combinedOutput -split "`r?`n" |
            Where-Object { $_ -match '(?i)SCRIPT ERROR:|(^|\s)ERROR:|CRASH:' }
    )
    $leakWarningLines = @(
        $combinedOutput -split "`r?`n" |
            Where-Object {
                $_ -match '(?i)ObjectDB.*(?:leak|orphan)|resources still in use at exit|orphan(?:ed)? (?:node|object|instance)|RID allocations.*leaked'
            }
    )
    if ($exitCode -ne 0) {
        throw "$Label exited with code $exitCode. See $masterLog"
    }
    if ($engineErrorLines.Count -gt 0) {
        throw "$Label emitted a script/engine error. See $masterLog"
    }
    if ($leakWarningLines.Count -gt 0) {
        throw "$Label emitted an ObjectDB/resource leak or orphan warning. See $masterLog"
    }
}

function Get-Sha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required release artifact is missing: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ReleaseAttemptFingerprint {
    $inputs = @(
        $layoutPath,
        $manifestPath,
        $referenceManifestPath,
        $verificationPolicyPath,
        $PSCommandPath,
        (Join-Path $projectPath "scripts\tests\run_twin_bays_splash_arena_ai_batch.ps1"),
        (Join-Path $projectPath "scripts\tests\run_twin_bays_splash_arena_performance.ps1"),
        (Join-Path $projectPath "scripts\tests\capture_twin_bays_splash_arena.gd"),
        (Join-Path $projectPath "scripts\globals\match_config.gd")
    )
    $records = foreach ($path in $inputs) {
        $resolved = (Resolve-Path -LiteralPath $path).Path
        "$($resolved.ToLowerInvariant())=$(Get-Sha256 -Path $resolved)"
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($records -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-ReleaseAttemptEntries {
    if (-not (Test-Path -LiteralPath $attemptLedgerPath -PathType Leaf)) {
        return @()
    }
    $ledger = Get-Content -LiteralPath $attemptLedgerPath -Raw | ConvertFrom-Json
    return @($ledger.attempts)
}

function Add-ReleaseAttemptEntry {
    param(
        [Parameter(Mandatory = $true)] [string]$Fingerprint,
        [Parameter(Mandatory = $true)] [ValidateSet("PASS", "FAIL")] [string]$Status,
        [string]$Message = ""
    )
    $entries = @(Get-ReleaseAttemptEntries)
    $entries += [pscustomobject][ordered]@{
        run_id = $runId
        fingerprint = $Fingerprint
        status = $Status
        release_reason = $ReleaseReason
        update_baseline = [bool]$UpdateBaseline
        override_retry_limit = [bool]$OverrideRetryLimit
        override_reason = $OverrideReason
        message = $Message
        generated_at_utc = [DateTime]::UtcNow.ToString('o')
    }
    [ordered]@{
        schema_version = 1
        policy = "res://resources/validation/twin_bays_verification_policy_v1.json"
        attempts = $entries
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $attemptLedgerPath -Encoding utf8
}

function Get-ReleaseArtifactBinding {
    $layoutSha = Get-Sha256 -Path $layoutPath
    $manifestSha = Get-Sha256 -Path $manifestPath
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([string]$manifest.layout_sha256 -ne $layoutSha) {
        throw "Twin Bays manifest is not bound to the current canonical layout."
    }

    $assets = [ordered]@{}
    foreach ($outputProperty in $manifest.outputs.PSObject.Properties) {
        $name = [string]$outputProperty.Name
        $relativePath = [string]$outputProperty.Value
        $filePath = Join-Path $projectPath $relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $actualSha = Get-Sha256 -Path $filePath
        $expectedProperty = $manifest.output_sha256.PSObject.Properties[$name]
        if ($null -eq $expectedProperty -or [string]$expectedProperty.Value -ne $actualSha) {
            throw "Twin Bays manifest output hash mismatch: $name"
        }
        $assets[$name] = [ordered]@{
            path = "res://$($relativePath.Replace('\', '/'))"
            sha256 = $actualSha
        }
    }

    $referenceManifestSha = Get-Sha256 -Path $referenceManifestPath
    $referenceManifest = Get-Content -LiteralPath $referenceManifestPath -Raw | ConvertFrom-Json
    if ([string]$referenceManifest.schema -ne "chaos_gun.twin_bays_as_built_reference" `
        -or [int]$referenceManifest.version -ne 1) {
        throw "Twin Bays as-built reference manifest schema/version is invalid."
    }
    if ([string]$referenceManifest.layout.sha256 -ne $layoutSha) {
        throw "Twin Bays as-built reference is not bound to the current canonical layout."
    }
    $referenceBoundFiles = [ordered]@{
        reference_as_built_image = $referenceManifest.output
        reference_frozen_godot_source = $referenceManifest.sources.godot_empty_capture
        reference_mood_only_image = $referenceManifest.sources.mood_reference_only
    }
    foreach ($referenceProperty in $referenceBoundFiles.GetEnumerator()) {
        $referenceRecord = $referenceProperty.Value
        $relativePath = [string]$referenceRecord.path
        $filePath = Join-Path $projectPath $relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $actualSha = Get-Sha256 -Path $filePath
        if ([string]$referenceRecord.sha256 -ne $actualSha) {
            throw "Twin Bays as-built reference hash mismatch: $($referenceProperty.Key)"
        }
        $assets[[string]$referenceProperty.Key] = [ordered]@{
            path = "res://$($relativePath.Replace('\', '/'))"
            sha256 = $actualSha
        }
    }
    $assets["reference_contract_manifest"] = [ordered]@{
        path = "res://docs/art-direction/references/twin_bays/twin_bays_as_built_reference_v1.json"
        sha256 = $referenceManifestSha
    }

    $textureSetsProperty = $manifest.PSObject.Properties["pbr_texture_sets"]
    if ($null -ne $textureSetsProperty) {
        foreach ($roleProperty in $textureSetsProperty.Value.PSObject.Properties) {
            $role = [string]$roleProperty.Name
            $textureSet = $roleProperty.Value
            foreach ($pathProperty in $textureSet.maps.PSObject.Properties) {
                $mapName = [string]$pathProperty.Name
                $assetName = "pbr_texture_${role}_${mapName}"
                $relativePath = [string]$pathProperty.Value
                $filePath = Join-Path $projectPath $relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
                $actualSha = Get-Sha256 -Path $filePath
                $expectedProperty = $textureSet.sha256.PSObject.Properties[$mapName]
                if ($null -eq $expectedProperty -or [string]$expectedProperty.Value -ne $actualSha) {
                    throw "Twin Bays manifest PBR texture hash mismatch: $role/$mapName"
                }
                $assets[$assetName] = [ordered]@{
                    path = "res://$($relativePath.Replace('\', '/'))"
                    sha256 = $actualSha
                }
            }
        }
    }

    # Import mode and the Windows production renderer materially affect
    # runtime memory, stability, and rendered evidence even when the GLB and
    # manifest bytes themselves are unchanged. Bind them alongside the
    # generated assets so a release run cannot silently drift back to
    # uncompressed extracted textures or the retired Windows driver.
    $runtimeConfigurationAssets = [ordered]@{
        runtime_project_config = "project.godot"
        runtime_foreground_import = "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_foreground.glb.import"
        runtime_hero_kit_import = "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_hero_kit.glb.import"
        runtime_performance_wrapper = "scripts/tests/run_twin_bays_splash_arena_performance.ps1"
        runtime_performance_script = "scripts/tests/twin_bays_splash_arena_performance.gd"
        runtime_capture_script = "scripts/tests/capture_twin_bays_splash_arena.gd"
        runtime_test_window_policy = "scripts/globals/test_window_policy.gd"
        runtime_verification_policy = "resources/validation/twin_bays_verification_policy_v1.json"
    }
    foreach ($runtimeProperty in $runtimeConfigurationAssets.GetEnumerator()) {
        $relativePath = [string]$runtimeProperty.Value
        $filePath = Join-Path $projectPath $relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $assets[[string]$runtimeProperty.Key] = [ordered]@{
            path = "res://$relativePath"
            sha256 = Get-Sha256 -Path $filePath
        }
    }

    return [ordered]@{
        layout = [ordered]@{
            path = "res://resources/maps/twin_bays_layout_v1.json"
            sha256 = $layoutSha
        }
        manifest = [ordered]@{
            path = "res://assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_manifest.json"
            sha256 = $manifestSha
            recorded_layout_sha256 = [string]$manifest.layout_sha256
        }
        reference = [ordered]@{
            manifest_path = "res://docs/art-direction/references/twin_bays/twin_bays_as_built_reference_v1.json"
            manifest_sha256 = $referenceManifestSha
            recorded_layout_sha256 = [string]$referenceManifest.layout.sha256
            pixel_comparison_required = $false
        }
        assets = $assets
    }
}

function Get-DirectoryHashMap {
    param([string]$Path)
    $hashes = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $hashes
    }
    foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse | Sort-Object FullName) {
        $relative = $file.FullName.Substring($Path.Length).TrimStart('\').Replace('\', '/')
        $hashes[$relative] = Get-Sha256 -Path $file.FullName
    }
    return $hashes
}

function Invoke-GodotScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [switch]$Rendered,

        [string[]]$UserArguments = @()
    )

    $arguments = @()
    if (-not $Rendered) {
        $arguments += @("--headless", "--audio-driver", "Dummy")
    } else {
        $arguments += @(
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--disable-vsync",
            "--windowed",
            "--position", "0,0"
        )
    }
    $arguments += @("--path", $projectPath, "-s", $ScriptPath)
    if ($UserArguments.Count -gt 0) {
        $arguments += "--"
        $arguments += $UserArguments
    }
    Invoke-CheckedProcess -Label $Label -FilePath $GodotPath -Arguments $arguments
}

$baselineExistedAtStart = Test-Path -LiteralPath $baselinePath -PathType Container
$baselineHashesAtStart = Get-DirectoryHashMap -Path $baselinePath
$releaseAttemptFingerprint = ""
if ($isFullGateRequest) {
    $releaseAttemptFingerprint = Get-ReleaseAttemptFingerprint
    $matchingAttempts = @(
        Get-ReleaseAttemptEntries |
            Where-Object { [string]$_.fingerprint -eq $releaseAttemptFingerprint }
    )
    $consecutiveFailures = 0
    for ($index = $matchingAttempts.Count - 1; $index -ge 0; $index--) {
        $status = [string]$matchingAttempts[$index].status
        if ($status -eq "PASS") { break }
        if ($status -eq "FAIL") { $consecutiveFailures++ }
    }
    Add-Content -LiteralPath $masterLog -Value @(
        "VerificationPolicy: $verificationPolicyPath",
        "ReleaseAttemptFingerprint: $releaseAttemptFingerprint",
        "ConsecutiveFailedAttempts: $consecutiveFailures/$maximumConsecutiveFailedAttempts",
        ""
    )
    if ($consecutiveFailures -ge $maximumConsecutiveFailedAttempts -and -not $OverrideRetryLimit) {
        throw "Retry limit reached for this unchanged release fingerprint. Diagnose or change the relevant implementation first; an exceptional retry requires -OverrideRetryLimit and -OverrideReason."
    }
}

try {
if ($RebuildAssets) {
    $rebuildScript = Join-Path $projectPath "tools\rebuild_twin_bays_splash_arena.ps1"
    if (-not (Test-Path -LiteralPath $rebuildScript -PathType Leaf)) {
        throw "Twin Bays rebuild wrapper is missing: $rebuildScript"
    }
    if (-not (Test-Path -LiteralPath $BlenderPath -PathType Leaf)) {
        throw "Blender executable not found: $BlenderPath"
    }
    Write-Host "[Rebuild deterministic Blender assets]"
    & $rebuildScript -BlenderExe $BlenderPath
    if ($LASTEXITCODE -ne 0) {
        throw "Twin Bays Blender rebuild failed with code $LASTEXITCODE"
    }
}

Invoke-CheckedProcess `
    -Label "Godot import" `
    -FilePath $GodotPath `
    -Arguments @("--headless", "--audio-driver", "Dummy", "--editor", "--path", $projectPath, "--import", "--quit")

$artifactBinding = Get-ReleaseArtifactBinding
Add-Content -LiteralPath $masterLog -Value @(
    "ArtifactBinding.LayoutSha256: $($artifactBinding.layout.sha256)",
    "ArtifactBinding.ManifestSha256: $($artifactBinding.manifest.sha256)",
    ""
)

Write-Host "`n=== Structure and production contract ==="
Invoke-GodotScript -Label "Open Ring-Out frozen-map regression" -ScriptPath "res://scripts/tests/open_ringout_slice_verifier.gd"
Invoke-GodotScript -Label "Whitebox structural regression" -ScriptPath "res://scripts/tests/twin_bays_whitebox_verifier.gd"
Invoke-GodotScript -Label "Production GLB structure metrics" -ScriptPath "res://scripts/tests/twin_bays_structure_metrics_verifier.gd"
Invoke-GodotScript -Label "Twin Bays geometry integrity" -ScriptPath "res://scripts/tests/twin_bays_geometry_integrity_verifier.gd"
Invoke-GodotScript -Label "Twin Bays shared base contract" -ScriptPath "res://scripts/tests/twin_bays_arena_base_contract_verifier.gd"
Invoke-GodotScript -Label "Production structure and visual contract" -ScriptPath "res://scripts/tests/twin_bays_splash_arena_verifier.gd"
Invoke-GodotScript -Label "Twin Bays visual-only ambient motion" -ScriptPath "res://scripts/tests/twin_bays_environment_ambient_motion_verifier.gd"
Invoke-GodotScript -Label "Open Ring-Out independent camera regression" -ScriptPath "res://scripts/tests/open_ringout_camera_verifier.gd"
Invoke-GodotScript -Label "Twin Bays shared party camera" -ScriptPath "res://scripts/tests/twin_bays_camera_verifier.gd"
Invoke-GodotScript -Label "Cross-map camera consistency" -ScriptPath "res://scripts/tests/party_shooter_camera_consistency_verifier.gd"

Write-Host "`n=== Shared character and weapon system ==="
Invoke-GodotScript -Label "Party shooter v1 profile" -ScriptPath "res://scripts/tests/party_shooter_profile_verifier.gd"
Invoke-GodotScript -Label "Hero character rig" -ScriptPath "res://scripts/tests/hero_character_rig_asset_verifier.gd"
Invoke-GodotScript -Label "Character weapon readability" -ScriptPath "res://scripts/tests/character_weapon_readability_verifier.gd"
Invoke-GodotScript -Label "Expanded shared weapon roster" -ScriptPath "res://scripts/tests/expanded_weapon_roster_verifier.gd"

Write-Host "`n=== Portal, spawn, pickup, fall, respawn, HUD, result, pause ==="
Invoke-GodotScript -Label "Twin Bays runtime flow" -ScriptPath "res://scripts/tests/twin_bays_splash_arena_runtime_verifier.gd"
Invoke-GodotScript -Label "Player-facing map routes" -ScriptPath "res://scripts/tests/playable_match_routes_open_ringout_verifier.gd"

Write-Host "`n=== Shared match presentation ==="
Invoke-GodotScript -Label "Party-shooter shared presentation contract" -ScriptPath "res://scripts/tests/party_shooter_match_presentation_verifier.gd"
Invoke-GodotScript -Label "Open Ring-Out presentation compatibility" -ScriptPath "res://scripts/tests/open_ringout_match_presentation_verifier.gd"
Invoke-GodotScript -Label "Twin Bays shared presentation integration" -ScriptPath "res://scripts/tests/twin_bays_match_presentation_verifier.gd"

if ($Quick) {
    Write-Host "`n=== Long-running gates skipped by explicit -Quick ==="
    Add-Content -LiteralPath $masterLog -Value @(
        "Long-running AI batch and performance benchmark were skipped by explicit -Quick.",
        "This is not a release-complete result.",
        ""
    )
} else {
    Write-Host "`n=== Fixed-seed 8 x 30 s AI batch ==="
    $aiWrapper = Join-Path $projectPath "scripts\tests\run_twin_bays_splash_arena_ai_batch.ps1"
    if (-not (Test-Path -LiteralPath $aiWrapper -PathType Leaf)) {
        throw "Twin Bays strict AI wrapper is missing: $aiWrapper"
    }
    $aiStageLog = Join-Path $workPath "twin_bays_ai_batch_strict_wrapper.combined.txt"
    Set-Content -LiteralPath $aiStageLog -Value ""
    Add-Content -LiteralPath $masterLog -Value @(
        "==================================================",
        "[Twin Bays strict AI batch wrapper]",
        "Combined stage log: $aiStageLog"
    )
    try {
        & $aiWrapper `
            -GodotPath $GodotPath `
            -ExpectedLayoutSha256 $artifactBinding.layout.sha256 `
            -ExpectedManifestSha256 $artifactBinding.manifest.sha256 *>&1 | ForEach-Object {
                $line = $_.ToString()
                Add-Content -LiteralPath $aiStageLog -Value $line
                Add-Content -LiteralPath $masterLog -Value $line
                Write-Host $line
            }
        Add-Content -LiteralPath $masterLog -Value @("EXIT=0", "")
    } catch {
        $aiError = $_.Exception.Message
        Add-Content -LiteralPath $aiStageLog -Value "ERROR: $aiError"
        Add-Content -LiteralPath $masterLog -Value @("EXIT=1", "ERROR: $aiError", "")
        throw
    }

    $aiReportPath = Join-Path $reportsPath "twin_bays_splash_arena_ai_batch.json"
    $aiReport = Get-Content -LiteralPath $aiReportPath -Raw | ConvertFrom-Json
    if ([string]$aiReport.artifact_binding.layout_sha256 -ne $artifactBinding.layout.sha256 `
        -or [string]$aiReport.artifact_binding.manifest_sha256 -ne $artifactBinding.manifest.sha256 `
        -or -not [bool]$aiReport.artifact_binding.stable_during_run) {
        throw "Strict AI report is not bound to the current stable layout and manifest."
    }
    $aiReportBinding = [ordered]@{
        path = "res://reports/twin_bays_splash_arena_ai_batch.json"
        sha256 = Get-Sha256 -Path $aiReportPath
        layout_sha256 = [string]$aiReport.artifact_binding.layout_sha256
        manifest_sha256 = [string]$aiReport.artifact_binding.manifest_sha256
    }
}

if (-not $SkipRender) {
    if (-not $Quick) {
        Write-Host "`n=== Forward+ matched performance gate ==="
        $performanceWrapper = Join-Path $projectPath "scripts\tests\run_twin_bays_splash_arena_performance.ps1"
        if (-not (Test-Path -LiteralPath $performanceWrapper -PathType Leaf)) {
            throw "Twin Bays performance wrapper is missing: $performanceWrapper"
        }
        # Invoke the wrapper in this PowerShell process. A nested PowerShell
        # launched through Start-Process inherits an extra background job layer
        # in the desktop runner and produced non-representative frame pacing.
        $performanceStageLog = Join-Path $workPath "twin_bays_forward_separate-process_performance.combined.txt"
        Set-Content -LiteralPath $performanceStageLog -Value ""
        Add-Content -LiteralPath $masterLog -Value @(
            "==================================================",
            "[Twin Bays Forward+ separate-process performance]",
            "Combined stage log: $performanceStageLog"
        )
        try {
            & $performanceWrapper -GodotPath $GodotPath *>&1 | ForEach-Object {
                $line = $_.ToString()
                Add-Content -LiteralPath $performanceStageLog -Value $line
                Add-Content -LiteralPath $masterLog -Value $line
                Write-Host $line
            }
            Add-Content -LiteralPath $masterLog -Value @("EXIT=0", "")
        } catch {
            $performanceError = $_.Exception.Message
            Add-Content -LiteralPath $performanceStageLog -Value "ERROR: $performanceError"
            Add-Content -LiteralPath $masterLog -Value @("EXIT=1", "ERROR: $performanceError", "")
            throw
        }
        $performanceReportPath = Join-Path $reportsPath "twin_bays_splash_arena_performance.json"
        $performanceReport = Get-Content -LiteralPath $performanceReportPath -Raw | ConvertFrom-Json
        if (-not [bool]$performanceReport.passed) {
            throw "Twin Bays paired performance report did not record a passing result."
        }
        $performanceReportBinding = [ordered]@{
            path = "res://reports/twin_bays_splash_arena_performance.json"
            sha256 = Get-Sha256 -Path $performanceReportPath
        }
    }

    Write-Host "`n=== Rendered release captures ==="
    $captures = @(
        @("empty",  "1536", "1024", "res://reports/twin_bays_splash_arena_empty_1536x1024.png"),
        @("battle", "1920", "1080", "res://reports/twin_bays_splash_arena_battle_1920x1080.png"),
        @("portal", "1920", "1080", "res://reports/twin_bays_splash_arena_portal_1920x1080.png"),
        @("mobile", "1280", "720",  "res://reports/twin_bays_splash_arena_mobile_1280x720.png"),
        @("left_portal", "1024", "1024", "res://reports/twin_bays_splash_arena_left_portal_1024.png"),
        @("right_portal", "1024", "1024", "res://reports/twin_bays_splash_arena_right_portal_1024.png"),
        @("ambient_start", "1536", "1024", "res://reports/twin_bays_splash_arena_ambient_start_1536x1024.png"),
        @("ambient_end", "1536", "1024", "res://reports/twin_bays_splash_arena_ambient_end_1536x1024.png"),
        @("intro_ready", "1920", "1080", "res://reports/twin_bays_splash_arena_intro_ready_1920x1080.png"),
        @("intro_go", "1920", "1080", "res://reports/twin_bays_splash_arena_intro_go_1920x1080.png"),
        @("winner", "1920", "1080", "res://reports/twin_bays_splash_arena_winner_1920x1080.png")
    )
    foreach ($capture in $captures) {
        $captureOutputPath = Join-Path $projectPath ($capture[3] -replace '^res://', '' -replace '/', '\')
        if (Test-Path -LiteralPath $captureOutputPath) {
            Remove-Item -LiteralPath $captureOutputPath -Force
        }
        Invoke-GodotScript `
            -Label "Twin Bays capture $($capture[0])" `
            -ScriptPath "res://scripts/tests/capture_twin_bays_splash_arena.gd" `
            -Rendered `
            -UserArguments @(
                "--mode=$($capture[0])",
                "--width=$($capture[1])",
                "--height=$($capture[2])",
                "--output=$($capture[3])"
            )
    }

    foreach ($capture in $captures) {
        $capturePath = Join-Path $projectPath ($capture[3] -replace '^res://', '' -replace '/', '\')
        if (-not (Test-Path -LiteralPath $capturePath -PathType Leaf)) {
            throw "Rendered capture is missing: $($capture[3])"
        }
        if ((Get-Item -LiteralPath $capturePath).Length -le 0) {
            throw "Rendered capture is empty: $($capture[3])"
        }
        $captureHashes[$capture[0]] = [ordered]@{
            path = $capture[3]
            width = [int]$capture[1]
            height = [int]$capture[2]
            sha256 = Get-Sha256 -Path $capturePath
        }
    }

    if ($UpdateBaseline) {
        New-Item -ItemType Directory -Path $baselinePath -Force | Out-Null
        foreach ($capture in $captures) {
            $source = Join-Path $projectPath ($capture[3] -replace '^res://', '' -replace '/', '\')
            $target = Join-Path $baselinePath (Split-Path $source -Leaf)
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
        Add-Content -LiteralPath $masterLog -Value "Golden captures explicitly updated: $baselinePath"
        Write-Host "Golden captures explicitly updated: $baselinePath"
    } else {
        Add-Content -LiteralPath $masterLog -Value "Golden captures preserved (no --update-baseline / -UpdateBaseline)."
        Write-Host "Golden captures preserved. Pass --update-baseline (alias of -UpdateBaseline) to update them explicitly."
    }
} else {
    Add-Content -LiteralPath $masterLog -Value "Rendered performance/captures skipped by explicit -SkipRender."
}

if (-not $UpdateBaseline) {
    $baselineExistsNow = Test-Path -LiteralPath $baselinePath -PathType Container
    $baselineHashesNow = Get-DirectoryHashMap -Path $baselinePath
    if ($baselineExistsNow -ne $baselineExistedAtStart `
        -or ($baselineHashesNow | ConvertTo-Json -Compress) -ne ($baselineHashesAtStart | ConvertTo-Json -Compress)) {
        throw "Golden baseline changed without explicit --update-baseline / -UpdateBaseline."
    }
}

$isFullGateRun = -not $Quick -and -not $SkipRender
if ($isFullGateRun) {
    if (-not (Test-Path -LiteralPath $baselinePath -PathType Container)) {
        throw "A complete release pass requires an existing Golden baseline. Create it only after approval with explicit --update-baseline / -UpdateBaseline, then rerun without that flag."
    }
    foreach ($capture in $captures) {
        $goldenCapturePath = Join-Path $baselinePath (Split-Path $capture[3] -Leaf)
        if (-not (Test-Path -LiteralPath $goldenCapturePath -PathType Leaf) `
            -or (Get-Item -LiteralPath $goldenCapturePath).Length -le 0) {
            throw "Golden baseline is incomplete: $goldenCapturePath"
        }
    }
}

$finalArtifactBinding = Get-ReleaseArtifactBinding
if (($finalArtifactBinding | ConvertTo-Json -Depth 20 -Compress) -ne ($artifactBinding | ConvertTo-Json -Depth 20 -Compress)) {
    throw "Layout, manifest, or generated asset hashes changed during release validation."
}

$isReleaseComplete = $isFullGateRun -and -not $UpdateBaseline
$resultLabel = if ($isReleaseComplete) {
    "RELEASE PASS"
} elseif ($isFullGateRun -and $UpdateBaseline) {
    "BASELINE UPDATE PASS (non-update rerun required)"
} else {
    "DEVELOPMENT PASS (release gates skipped)"
}
$releaseEvidence = [ordered]@{
    schema_version = 1
    run_id = $runId
    result = $resultLabel
    release_complete = $isReleaseComplete
    quick = [bool]$Quick
    skip_render = [bool]$SkipRender
    validation_policy = [ordered]@{
        path = "res://resources/validation/twin_bays_verification_policy_v1.json"
        sha256 = Get-Sha256 -Path $verificationPolicyPath
        release_candidate = [bool]$ReleaseCandidate
        release_reason = $ReleaseReason
        attempt_fingerprint = $releaseAttemptFingerprint
        override_retry_limit = [bool]$OverrideRetryLimit
        override_reason = $OverrideReason
    }
    artifact_binding = $finalArtifactBinding
    ai_report = $aiReportBinding
    performance_report = $performanceReportBinding
    captures = $captureHashes
    golden = [ordered]@{
        update_requested = [bool]$UpdateBaseline
        path = $baselinePath
        existed_at_start = $baselineExistedAtStart
        hashes_before = $baselineHashesAtStart
        hashes_after = Get-DirectoryHashMap -Path $baselinePath
    }
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
}
$releaseEvidence | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $releaseReportPath -Encoding utf8
if ($isFullGateRequest) {
    Add-ReleaseAttemptEntry -Fingerprint $releaseAttemptFingerprint -Status "PASS" -Message $resultLabel
}
Add-Content -LiteralPath $masterLog -Value @(
    "",
    "ReleaseEvidence: $releaseReportPath",
    "ReleaseEvidence.LayoutSha256: $($finalArtifactBinding.layout.sha256)",
    "ReleaseEvidence.ManifestSha256: $($finalArtifactBinding.manifest.sha256)",
    "ReleaseEvidence.AssetCount: $($finalArtifactBinding.assets.Count)",
    "ReleaseEvidence.CaptureCount: $($captureHashes.Count)",
    "Completed: $([DateTime]::UtcNow.ToString('o'))",
    "RESULT: $resultLabel"
)
Write-Host "`nTwin Bays validation $resultLabel"
Write-Host "Log: $masterLog"
} catch {
    $failureMessage = $_.Exception.Message
    if (Test-Path -LiteralPath $releaseReportPath -PathType Leaf) {
        Remove-Item -LiteralPath $releaseReportPath -Force
    }
    if ($isFullGateRequest -and -not [string]::IsNullOrWhiteSpace($releaseAttemptFingerprint)) {
        try {
            Add-ReleaseAttemptEntry -Fingerprint $releaseAttemptFingerprint -Status "FAIL" -Message $failureMessage
        } catch {
            Add-Content -LiteralPath $masterLog -Value "ATTEMPT_LEDGER_ERROR: $($_.Exception.Message)"
        }
    }
    Add-Content -LiteralPath $masterLog -Value @(
        "",
        "Completed: $([DateTime]::UtcNow.ToString('o'))",
        "RESULT: RELEASE FAIL",
        "ERROR: $failureMessage"
    )
    Write-Host "`nTwin Bays validation RELEASE FAIL"
    Write-Host "Log: $masterLog"
    throw
}
