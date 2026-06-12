[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$MatrixCsvFiles,
    [string]$OutputMarkdown = "docs/verification/potential_correction/artifacts/matrix_compare.md",
    [switch]$CompareFullHash
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($MatrixCsvFiles.Count -lt 2) {
    throw "Provide at least two matrix CSV files."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$outAbs = Join-Path $repoRoot $OutputMarkdown
$outParent = Split-Path -Parent $outAbs
if ($outParent -and -not (Test-Path -LiteralPath $outParent)) {
    New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}

function Load-MatrixRows {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Matrix CSV not found: $Path"
    }

    $rows = @(Import-Csv -LiteralPath $Path)
    if ($rows.Count -eq 0) {
        throw "Matrix CSV has no data rows: $Path"
    }
    return $rows
}

function Get-CaseMap {
    param([object[]]$Rows, [string]$Path)

    $map = @{}
    foreach ($row in $Rows) {
        $caseKey = [string]$row.case_index
        if ([string]::IsNullOrWhiteSpace($caseKey)) {
            throw "Missing case_index in $Path"
        }
        if ($map.ContainsKey($caseKey)) {
            throw "Duplicate case_index '$caseKey' in $Path"
        }
        $map[$caseKey] = $row
    }
    return $map
}

function Build-ConfigSignature {
    param([object]$Row)
    return @(
        "enable=$($Row.enable)",
        "min_opp_ici=$($Row.min_opposite_ici_count)",
        "min_fib=$($Row.min_fib_level)",
        "min_fib_trigger=$($Row.min_fib_trigger_mode)",
        "max_fib=$($Row.max_fib_level)",
        "max_fib_trigger=$($Row.max_fib_trigger_mode)",
        "extreme_eps=$($Row.extreme_touch_epsilon_points)",
        "extreme_touch_min=$($Row.extreme_touch_min_count)",
        "sup_dir=$($Row.supersede_direction_mode)",
        "sup_scope=$($Row.supersede_scope)",
        "fib_range_valid=$($Row.fib_range_valid)"
    ) -join "|"
}

$streams = @()
foreach ($f in $MatrixCsvFiles) {
    $rows = Load-MatrixRows -Path $f
    $map = Get-CaseMap -Rows $rows -Path $f
    $streams += [pscustomobject]@{
        file = $f
        rows = $rows
        map = $map
        count = $rows.Count
        run_id = [string]$rows[0].run_id
        symbol = [string]$rows[0].symbol
        source_timeframe = [string]$rows[0].source_timeframe
        context_timeframe = [string]$rows[0].context_timeframe
        execution_timeframe = [string]$rows[0].execution_timeframe
    }
}

$baseline = $streams[0]
$allPass = $true
$resultRows = @()

for ($i = 0; $i -lt $streams.Count; $i++) {
    $current = $streams[$i]
    $status = "PASS"
    $note = "Matches baseline"

    if ($i -gt 0) {
        if ($current.count -ne $baseline.count) {
            $status = "FAIL"
            $note = "Case count mismatch baseline=$($baseline.count) current=$($current.count)"
            $allPass = $false
        }
        else {
            $firstDiff = $null
            foreach ($caseKey in $baseline.map.Keys) {
                if (-not $current.map.ContainsKey($caseKey)) {
                    $firstDiff = "Missing case_index=$caseKey"
                    break
                }

                $baseRow = $baseline.map[$caseKey]
                $currRow = $current.map[$caseKey]

                $baseCfg = Build-ConfigSignature -Row $baseRow
                $currCfg = Build-ConfigSignature -Row $currRow
                if ($baseCfg -ne $currCfg) {
                    $firstDiff = "Config mismatch case=$caseKey baseline='$baseCfg' current='$currCfg'"
                    break
                }

                if ([string]$baseRow.selection_count -ne [string]$currRow.selection_count) {
                    $firstDiff = "Selection count mismatch case=$caseKey baseline=$($baseRow.selection_count) current=$($currRow.selection_count)"
                    break
                }
                if ([string]$baseRow.selection_hash -ne [string]$currRow.selection_hash) {
                    $firstDiff = "Selection hash mismatch case=$caseKey baseline=$($baseRow.selection_hash) current=$($currRow.selection_hash)"
                    break
                }
                if ($CompareFullHash -and ([string]$baseRow.full_hash -ne [string]$currRow.full_hash)) {
                    $firstDiff = "Full hash mismatch case=$caseKey baseline=$($baseRow.full_hash) current=$($currRow.full_hash)"
                    break
                }
            }

            if ($null -ne $firstDiff) {
                $status = "FAIL"
                $note = $firstDiff
                $allPass = $false
            }
        }
    }

    $resultRows += [pscustomobject]@{
        file = $current.file
        run_id = $current.run_id
        symbol = $current.symbol
        source_tf = $current.source_timeframe
        pair = "$($current.context_timeframe)/$($current.execution_timeframe)"
        case_count = $current.count
        status = $status
        note = $note
    }
}

$lines = @()
$lines += "# PotentialCorrection Matrix Comparison"
$lines += ""
$lines += "- Compared files: $($MatrixCsvFiles.Count)"
$lines += "- Compare full hash: $(if($CompareFullHash){'YES'}else{'NO'})"
$lines += "- Overall: $(if($allPass){'PASS'}else{'FAIL'})"
$lines += ""
$lines += "| File | RunId | Symbol | SourceTF | HTF/LTF | CaseCount | Status | Note |"
$lines += "|---|---|---|---|---|---:|---|---|"
foreach ($row in $resultRows) {
    $escapedNote = ($row.note -replace '\|', '\|')
    $lines += "| $($row.file) | $($row.run_id) | $($row.symbol) | $($row.source_tf) | $($row.pair) | $($row.case_count) | $($row.status) | $escapedNote |"
}

Set-Content -LiteralPath $outAbs -Value ($lines -join "`n") -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }

if (-not $allPass) {
    exit 1
}
