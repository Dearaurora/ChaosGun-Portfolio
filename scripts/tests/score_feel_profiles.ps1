[CmdletBinding()]
param(
    [string]$InputPath = "reports/feel/batch-latest.json",
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"

$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$batchPath = if ([System.IO.Path]::IsPathRooted($InputPath)) { $InputPath } else { Join-Path $projectPath $InputPath }
if (-not (Test-Path -LiteralPath $batchPath)) {
    throw "Batch report not found: $batchPath"
}

$batch = Get-Content -LiteralPath $batchPath -Raw | ConvertFrom-Json
$groups = $batch.results | Group-Object profile
$scores = foreach ($group in $groups) {
    $items = @($group.Group)
    $armed = ($items | Measure-Object armed_ai -Average).Average
    $deaths = ($items | Measure-Object deaths -Average).Average
    $ringOuts = ($items | Measure-Object ring_outs -Average).Average
    $pickups = ($items | Measure-Object max_pickups -Average).Average
    $firstDeaths = @($items | Where-Object { $null -ne $_.first_death_seconds } | Select-Object -ExpandProperty first_death_seconds)
    $firstDeathAvg = if ($firstDeaths.Count -gt 0) { ($firstDeaths | Measure-Object -Average).Average } else { $null }
    $timelyFirstDeaths = @($items | Where-Object {
        $null -ne $_.first_death_seconds -and $_.first_death_seconds -ge 4.0 -and $_.first_death_seconds -le 15.0
    }).Count
    $timelyFirstDeathRate = if ($items.Count -gt 0) { $timelyFirstDeaths / $items.Count } else { 0.0 }
    $deathlessRuns = @($items | Where-Object { $_.deaths -eq 0 }).Count
    $engagedRuns = $items.Count - $deathlessRuns
    $engagementRate = if ($items.Count -gt 0) { $engagedRuns / $items.Count } else { 0.0 }
    $deathValues = @($items | Select-Object -ExpandProperty deaths)
    $deathRange = if ($deathValues.Count -gt 0) {
        ($deathValues | Measure-Object -Maximum).Maximum - ($deathValues | Measure-Object -Minimum).Minimum
    } else {
        0
    }

    $score = 0.0
    $score += [Math]::Min($armed / 3.0, 1.0) * 25.0
    $score += [Math]::Min($deaths / 3.0, 1.0) * 25.0
    $score += [Math]::Min($ringOuts / 2.0, 1.0) * 25.0
    $score += [Math]::Min($pickups / 2.0, 1.0) * 10.0
    $score += $timelyFirstDeathRate * 15.0
    $score -= (1.0 - $engagementRate) * 15.0
    $score -= (1.0 - $timelyFirstDeathRate) * 5.0
    $score -= [Math]::Min($deathRange / 4.0, 1.0) * 5.0
    $score = [Math]::Max($score, 0.0)

    [pscustomobject]@{
        Profile = $group.Name
        Score = [Math]::Round($score, 2)
        ArmedAI = [Math]::Round($armed, 2)
        Deaths = [Math]::Round($deaths, 2)
        RingOuts = [Math]::Round($ringOuts, 2)
        EngagementRate = [Math]::Round($engagementRate, 2)
        TimelyFirstDeathRate = [Math]::Round($timelyFirstDeathRate, 2)
        DeathlessRuns = $deathlessRuns
        DeathRange = $deathRange
        MaxPickups = [Math]::Round($pickups, 2)
        FirstDeathSeconds = if ($null -ne $firstDeathAvg) { [Math]::Round($firstDeathAvg, 2) } else { $null }
        Runs = $items.Count
    }
}

$sortedScores = @($scores | Sort-Object Score -Descending)

if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
    $scorePath = if ([System.IO.Path]::IsPathRooted($OutPath)) { $OutPath } else { Join-Path $projectPath $OutPath }
    $scoreDir = Split-Path $scorePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($scoreDir)) {
        New-Item -ItemType Directory -Force -Path $scoreDir | Out-Null
    }
    [pscustomobject]@{
        source = $batchPath
        generated_at = (Get-Date).ToString("o")
        scores = $sortedScores
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $scorePath -Encoding UTF8
    Write-Output "Score report: $scorePath"
}

$sortedScores | Format-Table -AutoSize
