[CmdletBinding()]
param(
    [string]$OutputMarkdown = "docs/verification/2026-02-phase7a/artifacts/baseline_checkpoint.md",
    [string]$ManifestPath = "tools/config/manifest.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$outAbs = Join-Path $repoRoot $OutputMarkdown
$manifestAbs = Join-Path $repoRoot $ManifestPath

$outParent = Split-Path -Parent $outAbs
if ($outParent -and -not (Test-Path -LiteralPath $outParent)) {
    New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}

function Safe-Git {
    param([string[]]$GitArgs)
    try {
        return (& git @GitArgs 2>$null)
    }
    catch {
        return ""
    }
}

$commit = Safe-Git @("rev-parse", "--short", "HEAD")
$branch = Safe-Git @("rev-parse", "--abbrev-ref", "HEAD")
$status = Safe-Git @("status", "--short")

$registryPath = Join-Path $repoRoot "config/registry/profiles.json"
$schemaVersion = ""
if (Test-Path -LiteralPath $registryPath) {
    try {
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        $schemaVersion = [string]$registry.schema_version
    }
    catch {
        $schemaVersion = ""
    }
}

$runtimeFiles = @()
$runtimeRoot = Join-Path $repoRoot "Files/MOHY/config"
if (Test-Path -LiteralPath $runtimeRoot) {
    $runtimeFiles = Get-ChildItem -LiteralPath $runtimeRoot -Recurse -File | ForEach-Object {
        $_.FullName.Substring($repoRoot.Length + 1)
    }
}

$presetFiles = @()
$presetRoot = Join-Path $repoRoot "Presets/MOHY"
if (Test-Path -LiteralPath $presetRoot) {
    $presetFiles = Get-ChildItem -LiteralPath $presetRoot -Recurse -File | ForEach-Object {
        $_.FullName.Substring($repoRoot.Length + 1)
    }
}

$manifestPreview = @()
if (Test-Path -LiteralPath $manifestAbs) {
    $manifestPreview = Get-Content -LiteralPath $manifestAbs | Select-Object -First 12
}

$lines = @()
$lines += "# Phase 7A/7B Baseline Checkpoint"
$lines += ""
$lines += "- Captured UTC: $((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))"
$lines += "- Commit: $commit"
$lines += "- Branch: $branch"
$lines += "- Registry schema_version: $schemaVersion"
$lines += "- Scope lock: verification + tooling/docs only (no new strategy behavior)."
$lines += ""
$lines += "## Worktree Status"
if ($status -and $status.Count -gt 0) {
    $lines += '```text'
    $lines += $status
    $lines += '```'
}
else {
    $lines += "- clean"
}
$lines += ""
$lines += "## Runtime Config Artifacts Snapshot"
if ($runtimeFiles.Count -gt 0) {
    foreach ($f in $runtimeFiles) {
        $lines += "- $f"
    }
}
else {
    $lines += "- none found"
}
$lines += ""
$lines += "## Tester Set Artifacts Snapshot"
if ($presetFiles.Count -gt 0) {
    foreach ($f in $presetFiles) {
        $lines += "- $f"
    }
}
else {
    $lines += "- none found"
}
$lines += ""
$lines += "## Manifest Preview"
if ($manifestPreview.Count -gt 0) {
    $lines += '```csv'
    $lines += $manifestPreview
    $lines += '```'
}
else {
    $lines += ('- manifest not found at `{0}`' -f $ManifestPath)
}

Set-Content -LiteralPath $outAbs -Value ($lines -join "`n") -Encoding UTF8
Write-Output ("Baseline checkpoint written: {0}" -f $OutputMarkdown)
