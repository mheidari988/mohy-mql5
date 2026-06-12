[CmdletBinding()]
param(
    [string]$EvidenceRoot = "docs/verification/2026-02-phase6",
    [string]$BuildValidation = "docs/verification/2026-02-phase6/artifacts/non_backtest/build_gate_validation.md",
    [string]$AuditValidation = "docs/verification/2026-02-phase6/artifacts/non_backtest/audit_validation.md",
    [string]$NonBacktestMatrix = "docs/verification/2026-02-phase6/non_backtest_matrix.md",
    [string]$OutputMarkdown = "docs/verification/2026-02-phase6/artifacts/non_backtest/summary.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-OverallStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return "MISSING"
    }

    $line = Get-Content -LiteralPath $Path | Where-Object { $_ -match '^- Overall:\s+`?(PASS|FAIL|DEFERRED)`?' } | Select-Object -Last 1
    if ($line -and $line -match '(PASS|FAIL|DEFERRED)') {
        return $Matches[1]
    }

    $stateLine = Get-Content -LiteralPath $Path | Where-Object { $_ -match '^- State:\s+`?DEFERRED`?' } | Select-Object -Last 1
    if ($stateLine) {
        return "DEFERRED"
    }

    return "UNKNOWN"
}

function Get-HeadCommit {
    try {
        return (git rev-parse --short HEAD).Trim()
    } catch {
        return "UNKNOWN"
    }
}

function Get-WorktreeStatus {
    try {
        $statusLines = @(git status --porcelain)
        if ($statusLines.Count -eq 0) {
            return "clean"
        }
        return "dirty"
    } catch {
        return "unknown"
    }
}

$buildStatus = Parse-OverallStatus -Path $BuildValidation
$auditStatus = Parse-OverallStatus -Path $AuditValidation
$matrixExists = Test-Path -LiteralPath $NonBacktestMatrix
$commit = Get-HeadCommit
$worktree = Get-WorktreeStatus

$auditFiles = @()
if (Test-Path -LiteralPath "Files/MOHY/audit") {
    $auditFiles = @(Get-ChildItem -LiteralPath "Files/MOHY/audit" -Filter "*.csv" -File | Sort-Object Name | Select-Object -ExpandProperty Name)
}

$summaryLines = @()
$summaryLines += "# Phase 6 Non-Backtest Conformance Summary"
$summaryLines += ""
$summaryLines += "- Commit: $commit"
$summaryLines += "- Worktree status: $worktree"
$summaryLines += "- Build gate validation: $buildStatus ($BuildValidation)"
$summaryLines += "- UI audit validation: $auditStatus ($AuditValidation)"
$summaryLines += "- Non-backtest matrix present: $(if ($matrixExists) { "YES" } else { "NO" }) ($NonBacktestMatrix)"
$summaryLines += ""
$summaryLines += "## Referenced Audit CSV Files"
if ($auditFiles.Count -eq 0) {
    $summaryLines += "- None detected in Files/MOHY/audit."
} else {
    foreach ($name in $auditFiles) {
        $summaryLines += "- $name"
    }
}
$summaryLines += ""
$summaryLines += "## Sprint Gate"
$overall = if ($buildStatus -eq "PASS" -and $auditStatus -eq "PASS" -and $matrixExists) { "PASS" } else { "PARTIAL" }
$summaryLines += "- Overall: $overall"
$summaryLines += "- Note: Strategy Tester backtest matrix remains a separate manual gate."

$parent = Split-Path -Path $OutputMarkdown -Parent
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
Set-Content -LiteralPath $OutputMarkdown -Value ($summaryLines -join "`n") -Encoding UTF8

$summaryLines | ForEach-Object { Write-Output $_ }
