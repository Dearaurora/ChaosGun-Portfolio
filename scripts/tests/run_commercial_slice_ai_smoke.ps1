param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$stdoutPath = Join-Path $PSScriptRoot "..\..\godot_smoke_stdout.txt"
$stderrPath = Join-Path $PSScriptRoot "..\..\godot_smoke_stderr.txt"
$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

if (Test-Path Env:PATH) {
    Remove-Item Env:PATH -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $stdoutPath) {
    Remove-Item -LiteralPath $stdoutPath -Force
}

if (Test-Path -LiteralPath $stderrPath) {
    Remove-Item -LiteralPath $stderrPath -Force
}

$args = @(
    "--headless",
    "--path", $projectPath,
    "-s", "res://scripts/tests/commercial_slice_ai_smoke.gd"
)

$process = Start-Process `
    -FilePath $GodotPath `
    -ArgumentList $args `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -NoNewWindow `
    -PassThru `
    -Wait

$stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
$stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }

Write-Output "EXIT=$($process.ExitCode)"
Write-Output "--- STDOUT ---"
if ($stdout) {
    Write-Output $stdout.TrimEnd()
}
Write-Output "--- STDERR ---"
if ($stderr) {
    Write-Output $stderr.TrimEnd()
}

if ($process.ExitCode -ne 0) {
    throw "Godot AI smoke test exited with code $($process.ExitCode)"
}

if ($stderr -match "SCRIPT ERROR:" -or $stderr -match "(^|`n)ERROR:") {
    throw "Godot AI smoke test completed with engine or script errors."
}
