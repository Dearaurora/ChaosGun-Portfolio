param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$stdoutPath = Join-Path $PSScriptRoot "..\..\godot_sunset_v2_integration_stdout.txt"
$stderrPath = Join-Path $PSScriptRoot "..\..\godot_sunset_v2_integration_stderr.txt"
$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

if (Test-Path Env:PATH) {
    Remove-Item Env:PATH -ErrorAction SilentlyContinue
}

foreach ($logPath in @($stdoutPath, $stderrPath)) {
    if (Test-Path -LiteralPath $logPath) {
        Remove-Item -LiteralPath $logPath -Force
    }
}

$args = @(
    "--headless",
    "--path", $projectPath,
    "-s", "res://scripts/tests/sunset_open_ringout_v2_integration_verifier.gd"
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
    throw "Godot Sunset V2 integration verifier exited with code $($process.ExitCode)"
}

if ($stderr -match "SCRIPT ERROR:" -or $stderr -match "(^|`n)ERROR:") {
    throw "Godot Sunset V2 integration verifier completed with engine or script errors."
}

if ($stderr -match "ObjectDB instances leaked at exit" -or $stderr -match "resources still in use at exit") {
    throw "Godot Sunset V2 integration verifier completed with shutdown leak warnings."
}
