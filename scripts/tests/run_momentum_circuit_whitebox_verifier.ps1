param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$PythonPath = "python",
    [double]$Threshold = 0.95,
    [switch]$SkipCapture,
    [switch]$SkipCompare
)

$ErrorActionPreference = "Stop"
$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$capturePath = Join-Path $projectPath "reports\momentum_circuit_whitebox.png"
$overlayPath = Join-Path $projectPath "reports\momentum_circuit_whitebox_diff.png"
$referencePath = Join-Path $projectPath "docs\art-direction\references\map_concepts_round2\concept_d_folded_ribbon_circuit.png"
$comparatorPath = Join-Path $projectPath "tools\compare_momentum_circuit_reference.py"

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

Write-Output "MOMENTUM_CIRCUIT_RUN|phase=verify"
$verifyArgs = @(
    "--headless",
    "--audio-driver", "Dummy",
    "--path", $projectPath,
    "-s", "res://scripts/tests/momentum_circuit_whitebox_verifier.gd"
)
$verifyOutput = & $GodotPath @verifyArgs 2>&1
$verifyExit = $LASTEXITCODE
$verifyOutput | Write-Output
$verifyText = $verifyOutput -join "`n"
if ($verifyExit -ne 0) {
    throw "Momentum Circuit verifier exited with code $verifyExit"
}
if ($verifyText -notmatch "MOMENTUM_CIRCUIT_VERIFY_OK") {
    throw "Momentum Circuit verifier did not emit its success marker."
}
if ($verifyText -match "(?m)^(SCRIPT ERROR:|ERROR:)") {
    throw "Momentum Circuit verifier emitted an engine or script error."
}

if ($SkipCapture) {
    Write-Output "MOMENTUM_CIRCUIT_RUN_OK|verify=pass|capture=skipped|compare=skipped"
    return
}

Write-Output "MOMENTUM_CIRCUIT_RUN|phase=capture"
$captureArgs = @(
    "--audio-driver", "Dummy",
    "--display-driver", "windows",
    "--resolution", "960x540",
    "--path", $projectPath,
    "-s", "res://scripts/tests/capture_momentum_circuit_whitebox.gd",
    "--", "--output=res://reports/momentum_circuit_whitebox.png"
)
$captureOutput = & $GodotPath @captureArgs 2>&1
$captureExit = $LASTEXITCODE
$captureOutput | Write-Output
$captureText = $captureOutput -join "`n"
if ($captureExit -ne 0) {
    throw "Momentum Circuit capture exited with code $captureExit"
}
if ($captureText -notmatch "MOMENTUM_CIRCUIT_CAPTURE_OK") {
    throw "Momentum Circuit capture did not emit its success marker."
}
if ($captureText -match "(?m)^(SCRIPT ERROR:|ERROR:)") {
    throw "Momentum Circuit capture emitted an engine or script error."
}
if (-not (Test-Path -LiteralPath $capturePath)) {
    throw "Momentum Circuit capture file was not produced: $capturePath"
}

if ($SkipCompare) {
    Write-Output "MOMENTUM_CIRCUIT_RUN_OK|verify=pass|capture=pass|compare=skipped"
    return
}

if (-not (Test-Path -LiteralPath $referencePath)) {
    throw "Momentum Circuit reference not found: $referencePath"
}
if (-not (Test-Path -LiteralPath $comparatorPath)) {
    throw "Reference comparator not found: $comparatorPath"
}
if ($null -eq (Get-Command $PythonPath -ErrorAction SilentlyContinue)) {
    throw "Python executable not found: $PythonPath"
}

Write-Output "MOMENTUM_CIRCUIT_RUN|phase=compare|threshold=$Threshold"
$compareArgs = @(
    $comparatorPath,
    $capturePath,
    "--reference", $referencePath,
    "--threshold", $Threshold.ToString([System.Globalization.CultureInfo]::InvariantCulture),
    "--overlay-out", $overlayPath,
    "--strict"
)
$compareOutput = & $PythonPath @compareArgs 2>&1
$compareExit = $LASTEXITCODE
$compareOutput | Write-Output
if ($compareExit -ne 0) {
    throw "Momentum Circuit reference comparison failed at threshold $Threshold"
}

Write-Output "MOMENTUM_CIRCUIT_RUN_OK|verify=pass|capture=pass|compare=pass|threshold=$Threshold"
