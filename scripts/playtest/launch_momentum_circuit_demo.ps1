param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$WindowResolution = "960x540",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

$arguments = @(
    "--windowed",
    "--resolution", $WindowResolution,
    "--path", $projectPath,
    "--script", "res://scripts/playtest/momentum_circuit_demo_boot.gd"
)

Write-Output "Preset: momentum_circuit_public_demo_v3 (1 human + 3 AI)"
Write-Output "Map pool: Momentum Circuit is available at index 2"
Write-Output "Args: $($arguments -join ' ')"

if ($DryRun) {
    Write-Output "Dry run: Godot was not launched."
    return
}

Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $projectPath
