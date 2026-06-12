[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$JournalFiles,
    [ValidateSet("ExpectSame", "ExpectDifferent")]
    [string]$Expectation = "ExpectSame",
    [string]$OutputMarkdown = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($OutputMarkdown -eq "") {
    if ($Expectation -eq "ExpectSame") {
        $OutputMarkdown = "docs/verification/2026-02-phase7a/artifacts/config_hash_compare_same.md"
    }
    else {
        $OutputMarkdown = "docs/verification/2026-02-phase7a/artifacts/config_hash_compare_diff.md"
    }
}
$outAbs = Join-Path $repoRoot $OutputMarkdown
$outParent = Split-Path -Parent $outAbs
if ($outParent -and -not (Test-Path -LiteralPath $outParent)) {
    New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}

function Extract-Hashes {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Journal file not found: $Path"
    }

    $hits = @()
    $lines = Get-Content -LiteralPath $Path
    foreach ($line in $lines) {
        if ($line -match 'ConfigLoaded mode=([A-Za-z]+)\s+hash=([A-F0-9]{8})\s+layers=(.+)$') {
            $hits += [pscustomobject]@{
                mode = $Matches[1]
                hash = $Matches[2]
                layers = $Matches[3]
                line = $line
            }
        }
    }
    return $hits
}

$rows = @()
$allHashes = @()
$allPass = $true

foreach ($f in $JournalFiles) {
    $hits = Extract-Hashes -Path $f
    if ($hits.Count -eq 0) {
        $rows += [pscustomobject]@{
            file = $f
            hashes = ""
            modes = ""
            status = "FAIL"
            note = "No ConfigLoaded hash lines found"
        }
        $allPass = $false
        continue
    }

    $uniqHashes = @($hits.hash | Select-Object -Unique)
    $uniqModes = @($hits.mode | Select-Object -Unique)
    $allHashes += $uniqHashes

    $rows += [pscustomobject]@{
        file = $f
        hashes = ($uniqHashes -join ",")
        modes = ($uniqModes -join ",")
        status = "PASS"
        note = "Captured $($hits.Count) hash lines"
    }
}

$globalUniqueHashes = @($allHashes | Select-Object -Unique)
if ($Expectation -eq "ExpectSame") {
    if ($globalUniqueHashes.Count -ne 1) {
        $allPass = $false
    }
}
else {
    if ($globalUniqueHashes.Count -lt 2) {
        $allPass = $false
    }
}

if (-not $allPass) {
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($rows[$i].status -eq "PASS") {
            $rows[$i].status = "WARN"
        }
    }
}

$lines = @()
$lines += "# Config Hash Evidence Comparison"
$lines += ""
$lines += "- Expectation: $Expectation"
$lines += "- Files compared: $($JournalFiles.Count)"
$lines += "- Unique hashes found: $($globalUniqueHashes -join ', ')"
$lines += "- Overall: $(if($allPass){'PASS'}else{'FAIL'})"
$lines += ""
$lines += "| File | Modes | Hashes | Status | Note |"
$lines += "|---|---|---|---|---|"
foreach ($r in $rows) {
    $escapedNote = ($r.note -replace '\|', '\|')
    $lines += "| $($r.file) | $($r.modes) | $($r.hashes) | $($r.status) | $escapedNote |"
}

Set-Content -LiteralPath $outAbs -Value ($lines -join "`n") -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }

if (-not $allPass) {
    exit 1
}
