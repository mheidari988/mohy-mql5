[CmdletBinding()]
param(
    [string]$AuditRoot = "Files/MOHY/runtime",
    [string]$OutputMarkdown = "docs/verification/2026-03-phase5/artifacts/non_backtest/audit_refresh_baseline.md",
    [switch]$MoveCurrentToArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$timestamp = Get-Date
$ts = $timestamp.ToString("yyyy-MM-dd HH:mm:ss")
$folderStamp = $timestamp.ToString("yyyyMMdd_HHmmss")

if (-not (Test-Path -LiteralPath $AuditRoot)) {
    throw "Audit root not found: $AuditRoot"
}

$resolvedAuditRoot = (Resolve-Path -LiteralPath $AuditRoot).Path
$files = @(Get-ChildItem -LiteralPath $AuditRoot -Recurse -Filter "ui_audit.csv" -File | Sort-Object LastWriteTime, FullName)
$archiveDir = Join-Path $AuditRoot ("archive\" + $folderStamp)

if ($MoveCurrentToArchive -and $files.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $archiveDir)) {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    }

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($resolvedAuditRoot.Length).TrimStart('\')
        $destination = Join-Path $archiveDir $relativePath
        $destinationParent = Split-Path -Path $destination -Parent
        if ($destinationParent -and -not (Test-Path -LiteralPath $destinationParent)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }
        Move-Item -LiteralPath $file.FullName -Destination $destination -Force
    }

    $files = @()
}

$lines = @()
$lines += "# UI Audit Refresh Baseline"
$lines += ""
$lines += "- Generated at: $ts"
$lines += "- Audit root: $AuditRoot"
$lines += "- Move current to archive: $(if ($MoveCurrentToArchive) { 'YES' } else { 'NO' })"
if ($MoveCurrentToArchive) {
    $lines += "- Archive directory: $archiveDir"
}
$lines += ""
$lines += "## Existing Active Audit CSV Files"
if ($files.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($resolvedAuditRoot.Length).TrimStart('\')
        $lines += "- $relativePath | LastWrite=$($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) | Size=$($file.Length)"
    }
}
$lines += ""
$lines += "## Next Commands After Fresh UI Interaction"
$lines += "1. powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/validate_ui_audit.ps1 -MinLastWriteTime '$ts' -RequireDangerousChainEvidence"
$lines += "2. powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/run_build_gate.ps1"

$parent = Split-Path -Path $OutputMarkdown -Parent
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
Set-Content -LiteralPath $OutputMarkdown -Value ($lines -join "`n") -Encoding UTF8

$lines | ForEach-Object { Write-Output $_ }
