param(
    [string]$GodotExe = "E:\AITools\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe",
    [double]$SettleSeconds = 3.0
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw "Godot executable is missing: $GodotExe" }

$contractOutput = & python (Join-Path $root "tools\verify_twin_bays_art_v3_contract.py") 2>&1
$contractText = $contractOutput | Out-String
$contractText
if ($LASTEXITCODE -ne 0 -or $contractText -notmatch "TWIN_BAYS_ART_V3_CONTRACT_PASS") {
    throw "Art V3 authority contract failed"
}

$modes = @(
    "art_v3_full_dry",
    "art_v3_full_high",
    "art_v3_full_drain_0",
    "art_v3_full_drain_9",
    "art_v3_full_battle",
    "art_v3_full_mobile"
)
foreach ($mode in $modes) {
    $output = & $GodotExe --path $root --script res://scripts/tests/capture_twin_bays_splash_arena.gd -- --mode=$mode --settle=$SettleSeconds 2>&1
    $text = $output | Out-String
    $text
    if ($LASTEXITCODE -ne 0 `
        -or $text -match "SHADER ERROR|SCRIPT ERROR|TWIN_BAYS_CAPTURE_FAIL|\bERROR:" `
        -or $text -notmatch "TWIN_BAYS_CAPTURE_PASS") {
        throw "Art V3 full-map capture failed strict output validation: $mode"
    }
}

$verifyOutput = & $GodotExe --headless --path $root --script res://scripts/tests/twin_bays_art_v3_full_verifier.gd 2>&1
$verifyText = $verifyOutput | Out-String
$verifyText
if ($LASTEXITCODE -ne 0 `
    -or $verifyText -match "SCRIPT ERROR|TWIN_BAYS_ART_V3_FULL_VERIFY_FAIL|\bERROR:" `
    -or $verifyText -notmatch "TWIN_BAYS_ART_V3_FULL_VERIFY_PASS") {
    throw "Art V3 full-map runtime contract failed"
}

Write-Output "TWIN_BAYS_ART_V3_FULL_REVIEW_PASS_PENDING_HUMAN_APPROVAL"
Write-Output "Production Blend, GLBs, manifest and Golden were not updated."
