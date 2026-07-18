[CmdletBinding()]
param(
    [string]$GodotPath = "godot",
    [string]$FfmpegPath = "",
    [switch]$SkipFinalCapture
)

$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$reportDir = Join-Path $projectPath "reports\p31"
$framesDir = Join-Path $reportDir "frames"
$attemptDir = Join-Path $reportDir "attempts"
$mainScript = "res://scripts/tests/capture_p31_commercial_sample.gd"
$tailScript = "res://scripts/tests/capture_p31_match_tail.gd"
$mutex = $null
$mutexHeld = $false
$movieOverridePath = Join-Path $projectPath "override.cfg"
$movieOverrideOwned = $false

function Resolve-Executable([string]$Requested, [string]$Fallback) {
    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        if (Test-Path -LiteralPath $Requested) { return (Resolve-Path $Requested).Path }
        $command = Get-Command $Requested -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
        throw "Executable was not found: $Requested"
    }
    $command = Get-Command $Fallback -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "Executable was not found on PATH: $Fallback"
}

function Invoke-Godot([string]$Label, [string]$ScriptPath, [string[]]$Arguments) {
    Write-Host "P31_RUN|phase=$Label"
    $allArguments = @("--path", $projectPath, "--windowed", "--resolution", "1920x1080", "--fixed-fps", "60", "--script", $ScriptPath, "--") + $Arguments
    $output = & $script:godot @allArguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    $text = $output -join "`n"
    if ($exitCode -ne 0) { throw "$Label exited with code $exitCode" }
    if ($text -match "(?m)^(SCRIPT ERROR:|ERROR:|E 0:)") { throw "$Label emitted an engine or script error" }
    return $text
}

function Assert-JsonPass([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label did not write $Path" }
    $data = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    if (-not $data.pass) { throw "$Label report did not pass: $(Get-Content -Raw -LiteralPath $Path)" }
    return $data
}

function Get-MediaProbe([string]$Path) {
    $probePath = [System.IO.Path]::ChangeExtension($script:ffmpeg, ".exe")
    $ffprobe = Join-Path (Split-Path $script:ffmpeg -Parent) "ffprobe.exe"
    if (-not (Test-Path -LiteralPath $ffprobe)) { throw "ffprobe.exe is required beside ffmpeg.exe" }
    $json = & $ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate,nb_frames,duration -show_entries format=duration -of json $Path
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed for $Path" }
    return ($json -join "`n" | ConvertFrom-Json)
}

function Assert-Media([string]$Path, [string]$Label, [double]$ExpectedSeconds) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -le 0) { throw "$Label is missing or empty: $Path" }
    $probe = Get-MediaProbe $Path
    $stream = $probe.streams[0]
    if ([int]$stream.width -ne 1920 -or [int]$stream.height -ne 1080) { throw "$Label is not 1920x1080" }
    $duration = [double]$probe.format.duration
    if ([math]::Abs($duration - $ExpectedSeconds) -gt 0.12) { throw "$Label duration $duration is outside tolerance for $ExpectedSeconds" }
    $rateParts = ([string]$stream.avg_frame_rate).Split('/')
    $fps = if ($rateParts.Count -eq 2 -and [double]$rateParts[1] -ne 0.0) { [double]$rateParts[0] / [double]$rateParts[1] } else { [double]$stream.avg_frame_rate }
    if ([math]::Abs($fps - 60.0) -gt 0.01) { throw "$Label is not 60 fps (reported $fps)" }
    return [ordered]@{ path = $Path; width = [int]$stream.width; height = [int]$stream.height; fps = [string]$stream.avg_frame_rate; duration = $duration; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash }
}

function Get-EvidenceBinding {
    $paths = [ordered]@{
        commercial_script = "scripts/tests/capture_p31_commercial_sample.gd"
        tail_script = "scripts/tests/capture_p31_match_tail.gd"
        runner = "scripts/tests/run_p31_commercial_capture.ps1"
        open_ringout_scene = "scenes/maps/open_ringout_slice.tscn"
        open_ringout_script = "scripts/maps/open_ringout_slice.gd"
        hero_glb = "assets/models/generated/characters/hero_character_rig_v2.glb"
        projectile = "scripts/weapons/projectile.gd"
        hud = "scripts/ui/ringout_hud.gd"
    }
    $binding = [ordered]@{}
    foreach ($name in $paths.Keys) {
        $fullPath = Join-Path $projectPath $paths[$name]
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "P31 evidence file is missing: $($paths[$name])" }
        $binding[$name] = [ordered]@{ path = $paths[$name].Replace('\', '/'); sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash.ToLowerInvariant() }
    }
    return $binding
}

function Enable-MovieCaptureOverride {
    if (Test-Path -LiteralPath $script:movieOverridePath) {
        throw "P31 refuses to replace an existing override.cfg"
    }
    $content = @"
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=960
window/size/window_height_override=540
window/stretch/mode="viewport"
"@
    [System.IO.File]::WriteAllText($script:movieOverridePath, $content, [System.Text.UTF8Encoding]::new($false))
    $script:movieOverrideOwned = $true
}

function Disable-MovieCaptureOverride {
    if ($script:movieOverrideOwned -and (Test-Path -LiteralPath $script:movieOverridePath)) {
        Remove-Item -LiteralPath $script:movieOverridePath -Force
    }
    $script:movieOverrideOwned = $false
}

try {
    $script:godot = Resolve-Executable $GodotPath "godot"
    $script:ffmpeg = Resolve-Executable $FfmpegPath "ffmpeg"
    New-Item -ItemType Directory -Force -Path $reportDir, $framesDir, $attemptDir | Out-Null
    # Match the named render gate used by the existing capture/performance jobs.
    $mutex = [System.Threading.Mutex]::new($false, "Local\ChaosGun.RenderPerformanceGate")
    try { $mutexHeld = $mutex.WaitOne([TimeSpan]::FromMinutes(10)) }
    catch [System.Threading.AbandonedMutexException] { $mutexHeld = $true }
    if (-not $mutexHeld) { throw "Timed out waiting for the global ChaosGun render mutex" }

    $attempts = @()
    $successCount = 0
    for ($index = 1; $index -le 5; $index++) {
        $reportPath = Join-Path $attemptDir ("attempt_{0}.json" -f $index)
        if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath -Force }
        try {
            $text = Invoke-Godot "verification-$index" $mainScript @("--attempt=$index", "--audio=false", "--report=$reportPath")
            if ($text -notmatch "P31_COMMERCIAL_CAPTURE_PASS") { throw "Verification $index missed PASS marker" }
            $data = Assert-JsonPass $reportPath "Verification $index"
            $successCount++
            $attempts += [ordered]@{ attempt = $index; pass = $true; report = $reportPath; shot = [bool]$data.shot; hit = [bool]$data.hit; fall = [bool]$data.fall }
        } catch {
            $attempts += [ordered]@{ attempt = $index; pass = $false; error = $_.Exception.Message; report = $reportPath }
            Write-Warning "P31 verification $index failed: $($_.Exception.Message)"
        }
    }
    if ($successCount -lt 3) { throw "P31 requires at least 3/5 passing verification attempts; got $successCount" }

    $tailReport = Join-Path $reportDir "p31_match_tail.json"
    $tailText = Invoke-Godot "tail-verification" $tailScript @("--audio=false", "--report=$tailReport")
    if ($tailText -notmatch "P31_MATCH_TAIL_PASS") { throw "P31 tail verifier missed PASS marker" }
    $tailData = Assert-JsonPass $tailReport "P31 tail verifier"

    $artifacts = [ordered]@{}
    if (-not $SkipFinalCapture) {
        $mainAvi = Join-Path $reportDir "p31_commercial_sample.avi"
        $mainMp4 = Join-Path $reportDir "p31_commercial_sample.mp4"
        $tailAvi = Join-Path $reportDir "p31_match_tail.avi"
        $tailMp4 = Join-Path $reportDir "p31_match_tail.mp4"
        Remove-Item -LiteralPath $mainAvi, $mainMp4, $tailAvi, $tailMp4 -Force -ErrorAction SilentlyContinue
        Enable-MovieCaptureOverride
        $mainReport = Join-Path $reportDir "p31_final_capture.json"
        $mainArgs = @("--path", $projectPath, "--windowed", "--resolution", "1920x1080", "--fixed-fps", "60", "--write-movie", $mainAvi, "--script", $mainScript, "--", "--attempt=0", "--audio=true", "--report=$mainReport", "--frames-dir=$framesDir")
        $mainOutput = & $script:godot @mainArgs 2>&1
        $mainOutput | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0 -or ($mainOutput -join "`n") -notmatch "P31_COMMERCIAL_CAPTURE_PASS") { throw "Final P31 movie capture failed" }
        Assert-JsonPass $mainReport "Final P31 capture" | Out-Null
        & $script:ffmpeg -y -i $mainAvi -t 5.0 -map 0:v:0 -map "0:a?" -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart $mainMp4
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg conversion failed for the commercial sample; preserving AVI" }
        $artifacts.commercial = Assert-Media $mainMp4 "Commercial MP4" 5.0
        Remove-Item -LiteralPath $mainAvi -Force

        $tailArgs = @("--path", $projectPath, "--windowed", "--resolution", "1920x1080", "--fixed-fps", "60", "--write-movie", $tailAvi, "--script", $tailScript, "--", "--audio=true", "--report=$tailReport")
        $tailOutput = & $script:godot @tailArgs 2>&1
        $tailOutput | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0 -or ($tailOutput -join "`n") -notmatch "P31_MATCH_TAIL_PASS") { throw "Final P31 tail movie capture failed" }
        & $script:ffmpeg -y -i $tailAvi -t 2.5 -map 0:v:0 -map "0:a?" -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart $tailMp4
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg conversion failed for the tail sample; preserving AVI" }
        $artifacts.match_tail = Assert-Media $tailMp4 "Tail MP4" 2.5
        Remove-Item -LiteralPath $tailAvi -Force
        Disable-MovieCaptureOverride

        foreach ($size in @(@{ width = 1280; height = 720 }, @{ width = 2560; height = 1440 })) {
            $still = Join-Path $framesDir ("p31_action_apex_{0}x{1}.png" -f $size.width, $size.height)
            Remove-Item -LiteralPath $still -Force -ErrorAction SilentlyContinue
            $args = @("--path", $projectPath, "--windowed", "--resolution", ("{0}x{1}" -f $size.width, $size.height), "--fixed-fps", "60", "--script", $mainScript, "--", "--audio=false", "--width=$($size.width)", "--height=$($size.height)", "--still=action", "--output=$still")
            $stillOutput = & $script:godot @args 2>&1
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $still)) { throw "Action apex still failed at $($size.width)x$($size.height)" }
        }
        foreach ($name in @("p31_start.png", "p31_pickup_approach.png", "p31_pickup_confirm.png", "p31_armed_pose.png", "p31_crossfire.png", "p31_action_apex.png", "p31_fall.png", "p31_end.png", "p31_action_apex_1280x720.png", "p31_action_apex_2560x1440.png")) {
            $path = Join-Path $framesDir $name
            if (-not (Test-Path -LiteralPath $path)) { throw "Required P31 keyframe is missing: $path" }
            $artifacts[$name] = [ordered]@{ path = $path; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }
        }
    }

    $report = [ordered]@{
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        commands = [ordered]@{ godot = $script:godot; ffmpeg = $script:ffmpeg; main_script = $mainScript; tail_script = $tailScript; windowed = $true; fixed_fps = 60 }
        commit = (git -C $projectPath rev-parse HEAD 2>$null).Trim()
        evidence = Get-EvidenceBinding
        verification_attempts = $attempts
        success_count = $successCount
        required_success_count = 3
        tail = $tailData
        artifacts = $artifacts
        pass = $true
    }
    $reportPath = Join-Path $reportDir "p31_capture_report.json"
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8
    Write-Output "P31_CAPTURE_RUN_PASS|success_count=$successCount|report=$reportPath"
} finally {
    Disable-MovieCaptureOverride
    if ($mutexHeld -and $mutex) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
