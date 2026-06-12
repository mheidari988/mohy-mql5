[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MatrixCsv,
    [Parameter(Mandatory = $true)]
    [string]$AssertionsCsv,
    [string]$OutputMarkdown = "docs/verification/potential_correction/artifacts/matrix_summary.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $MatrixCsv)) {
    throw "Matrix CSV not found: $MatrixCsv"
}
if (-not (Test-Path -LiteralPath $AssertionsCsv)) {
    throw "Assertions CSV not found: $AssertionsCsv"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$outAbs = Join-Path $repoRoot $OutputMarkdown
$outParent = Split-Path -Parent $outAbs
if ($outParent -and -not (Test-Path -LiteralPath $outParent)) {
    New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}

$rows = @(Import-Csv -LiteralPath $MatrixCsv)
if ($rows.Count -eq 0) {
    throw "Matrix CSV has no data rows: $MatrixCsv"
}
$assertions = @(Import-Csv -LiteralPath $AssertionsCsv)
if ($assertions.Count -eq 0) {
    throw "Assertions CSV has no data rows: $AssertionsCsv"
}

$runId = [string]$rows[0].run_id
$symbol = [string]$rows[0].symbol
$sourceTf = [string]$rows[0].source_timeframe
$pair = "{0}/{1}" -f ([string]$rows[0].context_timeframe), ([string]$rows[0].execution_timeframe)

$selectionCounts = @($rows | ForEach-Object { [int]$_.selection_count })
$totalSelections = ($selectionCounts | Measure-Object -Sum).Sum
$minSelections = ($selectionCounts | Measure-Object -Minimum).Minimum
$maxSelections = ($selectionCounts | Measure-Object -Maximum).Maximum
$avgSelections = [math]::Round(($totalSelections / [double]$rows.Count), 4)

$confirmedCounts = @($rows | ForEach-Object { [int]$_.confirmed_count })
$formingCounts = @($rows | ForEach-Object { [int]$_.forming_count })
$invalidatedCounts = @($rows | ForEach-Object { [int]$_.invalidated_count })
$maxFibInvalidatedCounts = @($rows | ForEach-Object { [int]$_.invalidated_max_fib_count })
$doubleExtremeInvalidatedCounts = @($rows | ForEach-Object { [int]$_.invalidated_double_extreme_count })
$supersedeInvalidatedCounts = @($rows | ForEach-Object { [int]$_.invalidated_supersede_count })

$confirmedTotal = ($confirmedCounts | Measure-Object -Sum).Sum
$formingTotal = ($formingCounts | Measure-Object -Sum).Sum
$invalidatedTotal = ($invalidatedCounts | Measure-Object -Sum).Sum
$maxFibInvalidatedTotal = ($maxFibInvalidatedCounts | Measure-Object -Sum).Sum
$doubleExtremeInvalidatedTotal = ($doubleExtremeInvalidatedCounts | Measure-Object -Sum).Sum
$supersedeInvalidatedTotal = ($supersedeInvalidatedCounts | Measure-Object -Sum).Sum

$passAssertions = @($assertions | Where-Object { [string]$_.pass -eq "1" -or [string]$_.pass -eq "True" })
$failAssertions = @($assertions | Where-Object { [string]$_.pass -eq "0" -or [string]$_.pass -eq "False" })

$lines = @()
$lines += "# PotentialCorrection Matrix Summary"
$lines += ""
$lines += "- Run ID: $runId"
$lines += "- Symbol: $symbol"
$lines += "- Source TF: $sourceTf"
$lines += "- HTF/LTF: $pair"
$lines += "- Matrix rows: $($rows.Count)"
$lines += "- Selection count total: $totalSelections"
$lines += "- Selection count min/max/avg: $minSelections / $maxSelections / $avgSelections"
$lines += "- State totals (Confirmed / Forming / Invalidated): $confirmedTotal / $formingTotal / $invalidatedTotal"
$lines += "- Invalidation totals (MaxFib / DoubleExtreme / Supersede): $maxFibInvalidatedTotal / $doubleExtremeInvalidatedTotal / $supersedeInvalidatedTotal"
$lines += "- Assertions: $($passAssertions.Count) PASS, $($failAssertions.Count) FAIL"
$lines += "- Overall: $(if($failAssertions.Count -eq 0){'PASS'}else{'FAIL'})"
$lines += ""
$lines += "## Assertions"
$lines += ""
$lines += "| Rule | Pass | Violations | Sample |"
$lines += "|---|---|---:|---|"
foreach ($a in $assertions) {
    $passText = if ([string]$a.pass -eq "1" -or [string]$a.pass -eq "True") { "PASS" } else { "FAIL" }
    $escapedSample = ([string]$a.sample -replace '\|', '\|')
    $lines += "| $([string]$a.rule_id) | $passText | $([string]$a.violation_count) | $escapedSample |"
}

Set-Content -LiteralPath $outAbs -Value ($lines -join "`n") -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }

if ($failAssertions.Count -gt 0) {
    exit 1
}
