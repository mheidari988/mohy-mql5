[CmdletBinding()]
param(
    [string]$CompileLog = "docs/verification/mt5_migration/artifacts/compile_visualizer.log",
    [string]$SyntaxLog = "docs/verification/mt5_migration/artifacts/syntax_visualizer.log",
    [string]$ExpertCompileLog = "docs/verification/mt5_migration/artifacts/compile_ea.log",
    [string]$ExpertSyntaxLog = "docs/verification/mt5_migration/artifacts/syntax_ea.log",
    [string]$ExpertTarget = "Experts/MOHY_TradeEA.mq5",
    [string]$OutputMarkdown = "docs/verification/mt5_migration/artifacts/build_gate_validation.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-ZeroErrorsMarker {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Path        = $Path
            Exists      = $false
            Pass        = $false
            Evidence    = ""
            ErrorReason = "FileMissing"
        }
    }

    $lines = Get-Content -LiteralPath $Path
    $match = $lines | Where-Object { $_ -match '(?i)\bresult\b.*\b0 errors\b' } | Select-Object -Last 1
    return [pscustomobject]@{
        Path        = $Path
        Exists      = $true
        Pass        = [bool]$match
        Evidence    = if ($match) { $match.Trim() } else { "" }
        ErrorReason = if ($match) { "" } else { "NoZeroErrorResultMarker" }
    }
}

function To-Status([bool]$Pass) {
    if ($Pass) { return "PASS" }
    return "FAIL"
}

$compile = Test-ZeroErrorsMarker -Path $CompileLog
$syntax = Test-ZeroErrorsMarker -Path $SyntaxLog
$expertCompile = Test-ZeroErrorsMarker -Path $ExpertCompileLog
$expertSyntax = Test-ZeroErrorsMarker -Path $ExpertSyntaxLog
$overallPass = $compile.Pass -and $syntax.Pass -and $expertCompile.Pass -and $expertSyntax.Pass

$lines = @()
$lines += "# Build Gate Validation (MT5)"
$lines += ""
$lines += "- Targets:"
$lines += "  - Indicators/MOHY_Visualizer.mq5"
$lines += "  - $ExpertTarget"
$lines += "- Compile log: $($compile.Path)"
$lines += "- Compile status: $(To-Status $compile.Pass)"
if ($compile.Evidence -ne "") {
    $lines += "- Compile evidence: $($compile.Evidence)"
}
if ($compile.ErrorReason -ne "") {
    $lines += "- Compile error: $($compile.ErrorReason)"
}
$lines += "- Syntax log: $($syntax.Path)"
$lines += "- Syntax status: $(To-Status $syntax.Pass)"
if ($syntax.Evidence -ne "") {
    $lines += "- Syntax evidence: $($syntax.Evidence)"
}
if ($syntax.ErrorReason -ne "") {
    $lines += "- Syntax error: $($syntax.ErrorReason)"
}
$lines += "- Expert compile log: $($expertCompile.Path)"
$lines += "- Expert compile status: $(To-Status $expertCompile.Pass)"
if ($expertCompile.Evidence -ne "") {
    $lines += "- Expert compile evidence: $($expertCompile.Evidence)"
}
if ($expertCompile.ErrorReason -ne "") {
    $lines += "- Expert compile error: $($expertCompile.ErrorReason)"
}
$lines += "- Expert syntax log: $($expertSyntax.Path)"
$lines += "- Expert syntax status: $(To-Status $expertSyntax.Pass)"
if ($expertSyntax.Evidence -ne "") {
    $lines += "- Expert syntax evidence: $($expertSyntax.Evidence)"
}
if ($expertSyntax.ErrorReason -ne "") {
    $lines += "- Expert syntax error: $($expertSyntax.ErrorReason)"
}
$lines += "- Overall: $(To-Status $overallPass)"

$parent = Split-Path -Path $OutputMarkdown -Parent
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
Set-Content -LiteralPath $OutputMarkdown -Value ($lines -join "`n") -Encoding UTF8

$lines | ForEach-Object { Write-Output $_ }

if (-not $overallPass) {
    exit 1
}
