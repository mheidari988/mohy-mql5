[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$JournalFiles,
    [string]$OutputMarkdown = "docs/verification/2026-02-phase7a/artifacts/determinism_compare.md",
    [string[]]$IncludePatterns = @(
        "SetupTransition",
        "TradeTransition",
        "Reject",
        "Invalidation",
        "PendingRiskRecalc",
        "PendingReplace",
        "PendingModifyFail",
        "PendingReplaceFail"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($JournalFiles.Count -lt 2) {
    throw "Provide at least two journal files for determinism comparison."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$outAbs = Join-Path $repoRoot $OutputMarkdown
$outParent = Split-Path -Parent $outAbs
if ($outParent -and -not (Test-Path -LiteralPath $outParent)) {
    New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}

function Normalize-Line {
    param([string]$Line)

    $out = $Line.Trim()
    $out = [regex]::Replace($out, '^\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}(\.\d+)?\s+', '')
    $mohyIx = $out.IndexOf("MOHY | ")
    if ($mohyIx -ge 0) {
        $out = $out.Substring($mohyIx)
    }
    $out = [regex]::Replace($out, '\s+', ' ')
    return $out.Trim()
}

function Extract-CanonicalStream {
    param([string]$Path, [string[]]$Patterns)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Journal file not found: $Path"
    }
    $result = @()
    $lines = Get-Content -LiteralPath $Path
    foreach ($line in $lines) {
        $hit = $false
        foreach ($p in $Patterns) {
            if ($line -like "*$p*") {
                $hit = $true
                break
            }
        }
        if ($hit) {
            $result += Normalize-Line -Line $line
        }
    }
    return $result
}

$streams = @()
foreach ($f in $JournalFiles) {
    $stream = Extract-CanonicalStream -Path $f -Patterns $IncludePatterns
    $streams += [pscustomobject]@{
        File = $f
        Stream = $stream
        Count = $stream.Count
    }
}

$baseline = $streams[0]
$allPass = $true
$rows = @()

for ($i = 0; $i -lt $streams.Count; $i++) {
    $current = $streams[$i]
    $status = "PASS"
    $note = "Matches baseline"

    if ($i -gt 0) {
        if ($current.Count -ne $baseline.Count) {
            $status = "FAIL"
            $note = "Count mismatch baseline=$($baseline.Count) current=$($current.Count)"
            $allPass = $false
        }
        else {
            $firstDiff = -1
            for ($k = 0; $k -lt $baseline.Count; $k++) {
                if ($baseline.Stream[$k] -ne $current.Stream[$k]) {
                    $firstDiff = $k
                    break
                }
            }
            if ($firstDiff -ge 0) {
                $status = "FAIL"
                $note = "First diff index=$firstDiff baseline='$($baseline.Stream[$firstDiff])' current='$($current.Stream[$firstDiff])'"
                $allPass = $false
            }
        }
    }

    $rows += [pscustomobject]@{
        file = $current.File
        event_count = $current.Count
        status = $status
        note = $note
    }
}

$lines = @()
$lines += "# Determinism Stream Comparison"
$lines += ""
$lines += "- Compared files: $($JournalFiles.Count)"
$lines += "- Include patterns: $($IncludePatterns -join ', ')"
$lines += "- Overall: $(if($allPass){'PASS'}else{'FAIL'})"
$lines += ""
$lines += "| File | EventCount | Status | Note |"
$lines += "|---|---:|---|---|"
foreach ($r in $rows) {
    $escapedNote = ($r.note -replace '\|', '\|')
    $lines += "| $($r.file) | $($r.event_count) | $($r.status) | $escapedNote |"
}

Set-Content -LiteralPath $outAbs -Value ($lines -join "`n") -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }

if (-not $allPass) {
    exit 1
}
