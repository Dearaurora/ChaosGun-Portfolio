param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [int]$Runs = 8
)

$ErrorActionPreference = "Stop"

if ($Runs -lt 1) {
    throw "Runs must be at least 1."
}

$results = @()

for ($i = 1; $i -le $Runs; $i++) {
    $output = & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run_commercial_slice_ai_smoke.ps1") -GodotPath $GodotPath 2>&1 | Out-String

    $armed = if ($output -match 'AI armed at least once:\s+(\d+)') { [int]$matches[1] } else { throw "Could not parse armed AI count from run $i." }
    $deaths = if ($output -match 'Total deaths observed:\s+(\d+)') { [int]$matches[1] } else { throw "Could not parse death count from run $i." }
    $ringOuts = if ($output -match 'Suspected ring-out deaths:\s+(\d+)') { [int]$matches[1] } else { throw "Could not parse ring-out count from run $i." }
    $maxPickups = if ($output -match 'Max simultaneous pickups observed:\s+(\d+)') { [int]$matches[1] } else { throw "Could not parse max pickup count from run $i." }
    $maxClusters = if ($output -match 'Max simultaneous pickup clusters observed:\s+(\d+)') { [int]$matches[1] } else { throw "Could not parse max pickup cluster count from run $i." }
    $firstDeath = if ($output -match 'First death at:\s+([0-9.]+)s') { [double]$matches[1] } else { $null }

    $results += [pscustomobject]@{
        Run = $i
        Armed = $armed
        Deaths = $deaths
        RingOuts = $ringOuts
        MaxPickups = $maxPickups
        MaxClusters = $maxClusters
        FirstDeathSeconds = $firstDeath
    }
}

$results | Format-Table -AutoSize
Write-Output ""

function Format-RangeAverage {
    param(
        [string]$Label,
        [array]$Values,
        [string]$FormatString = "N2"
    )

    $measure = $Values | Measure-Object -Average -Minimum -Maximum
    $average = [string]::Format("{0:$FormatString}", $measure.Average)
    $minimum = [string]::Format("{0:$FormatString}", $measure.Minimum)
    $maximum = [string]::Format("{0:$FormatString}", $measure.Maximum)
    Write-Output ("{0}: avg {1}, min {2}, max {3}" -f $Label, $average, $minimum, $maximum)
}

Format-RangeAverage -Label "Armed AI" -Values ($results | Select-Object -ExpandProperty Armed) -FormatString "N2"
Format-RangeAverage -Label "Deaths" -Values ($results | Select-Object -ExpandProperty Deaths) -FormatString "N2"
Format-RangeAverage -Label "Ring-outs" -Values ($results | Select-Object -ExpandProperty RingOuts) -FormatString "N2"
Format-RangeAverage -Label "Max pickups" -Values ($results | Select-Object -ExpandProperty MaxPickups) -FormatString "N2"
Format-RangeAverage -Label "Max pickup clusters" -Values ($results | Select-Object -ExpandProperty MaxClusters) -FormatString "N2"

$firstDeathValues = $results | Where-Object { $_.FirstDeathSeconds -ne $null } | Select-Object -ExpandProperty FirstDeathSeconds
if ($firstDeathValues.Count -gt 0) {
    Format-RangeAverage -Label "First death (s)" -Values $firstDeathValues -FormatString "N2"
}
