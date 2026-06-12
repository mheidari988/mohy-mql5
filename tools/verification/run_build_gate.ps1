[CmdletBinding()]
param(
    [string]$MetaEditorPath = "C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe",
    [string]$MqlRoot = "",
    [string]$IndicatorRelativePath = "Indicators/MOHY_Visualizer.mq5",
    [string]$ExpertRelativePath = "Experts/MOHY_TradeEA.mq5",
    [string]$CompileLog = "docs/verification/mt5_migration/artifacts/compile_visualizer.log",
    [string]$SyntaxLog = "docs/verification/mt5_migration/artifacts/syntax_visualizer.log",
    [string]$ExpertCompileLog = "docs/verification/mt5_migration/artifacts/compile_ea.log",
    [string]$ExpertSyntaxLog = "docs/verification/mt5_migration/artifacts/syntax_ea.log",
    [string]$ValidatorScript = "tools/verification/validate_build_gate.ps1",
    [string]$ValidatorOutputMarkdown = "docs/verification/mt5_migration/artifacts/build_gate_validation.md",
    [switch]$SkipValidate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($MqlRoot -eq "") {
    $MqlRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
else {
    $MqlRoot = (Resolve-Path $MqlRoot).Path
}

if (-not (Test-Path -LiteralPath $MetaEditorPath)) {
    throw "MetaEditor not found at '$MetaEditorPath'."
}

$indicatorPath = Join-Path $MqlRoot $IndicatorRelativePath
if (-not (Test-Path -LiteralPath $indicatorPath)) {
    throw "Indicator not found at '$indicatorPath'."
}
$expertPath = Join-Path $MqlRoot $ExpertRelativePath
if (-not (Test-Path -LiteralPath $expertPath)) {
    throw "Expert not found at '$expertPath'."
}

$compileLogAbs = Join-Path $MqlRoot $CompileLog
$syntaxLogAbs = Join-Path $MqlRoot $SyntaxLog
$expertCompileLogAbs = Join-Path $MqlRoot $ExpertCompileLog
$expertSyntaxLogAbs = Join-Path $MqlRoot $ExpertSyntaxLog
$validatorAbs = Join-Path $MqlRoot $ValidatorScript
$validatorOutAbs = Join-Path $MqlRoot $ValidatorOutputMarkdown

$compileParent = Split-Path -Parent $compileLogAbs
$syntaxParent = Split-Path -Parent $syntaxLogAbs
$expertCompileParent = Split-Path -Parent $expertCompileLogAbs
$expertSyntaxParent = Split-Path -Parent $expertSyntaxLogAbs
$validatorParent = Split-Path -Parent $validatorOutAbs
if ($compileParent -and -not (Test-Path -LiteralPath $compileParent)) { New-Item -ItemType Directory -Path $compileParent -Force | Out-Null }
if ($syntaxParent -and -not (Test-Path -LiteralPath $syntaxParent)) { New-Item -ItemType Directory -Path $syntaxParent -Force | Out-Null }
if ($expertCompileParent -and -not (Test-Path -LiteralPath $expertCompileParent)) { New-Item -ItemType Directory -Path $expertCompileParent -Force | Out-Null }
if ($expertSyntaxParent -and -not (Test-Path -LiteralPath $expertSyntaxParent)) { New-Item -ItemType Directory -Path $expertSyntaxParent -Force | Out-Null }
if ($validatorParent -and -not (Test-Path -LiteralPath $validatorParent)) { New-Item -ItemType Directory -Path $validatorParent -Force | Out-Null }

function Invoke-MetaEditorPass {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)][bool]$SyntaxOnly,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $args = @(
        "/compile:$SourcePath",
        "/include:$MqlRoot",
        "/log:$LogPath"
    )
    if ($SyntaxOnly) {
        $args += "/s"
    }

    $mode = if ($SyntaxOnly) { "Syntax" } else { "Compile" }
    Write-Output ("Running {0} pass for {1}..." -f $mode, $Label)
    $proc = Start-Process -FilePath $MetaEditorPath -ArgumentList $args -Wait -PassThru
    Write-Output ("{0} exit code ({1}): {2}" -f $mode, $Label, $proc.ExitCode)
    if ($proc.ExitCode -ne 0) {
        Write-Warning ("MetaEditor {0} returned non-zero exit code {1} for {2}; proceeding to log validation." -f $mode, $proc.ExitCode, $Label)
    }
}

Invoke-MetaEditorPass -SourcePath $indicatorPath -LogPath $compileLogAbs -SyntaxOnly:$false -Label "MOHY_Visualizer"
Invoke-MetaEditorPass -SourcePath $indicatorPath -LogPath $syntaxLogAbs -SyntaxOnly:$true -Label "MOHY_Visualizer"
$expertLabel = [System.IO.Path]::GetFileNameWithoutExtension($ExpertRelativePath)
Invoke-MetaEditorPass -SourcePath $expertPath -LogPath $expertCompileLogAbs -SyntaxOnly:$false -Label $expertLabel
Invoke-MetaEditorPass -SourcePath $expertPath -LogPath $expertSyntaxLogAbs -SyntaxOnly:$true -Label $expertLabel

Write-Output ("Compile log written: {0}" -f $CompileLog)
Write-Output ("Syntax log written: {0}" -f $SyntaxLog)
Write-Output ("Expert compile log written: {0}" -f $ExpertCompileLog)
Write-Output ("Expert syntax log written: {0}" -f $ExpertSyntaxLog)

if (-not $SkipValidate) {
    if (-not (Test-Path -LiteralPath $validatorAbs)) {
        throw "Validator script not found at '$validatorAbs'."
    }

    Write-Output "Running build gate validator..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validatorAbs `
        -CompileLog $CompileLog `
        -SyntaxLog $SyntaxLog `
        -ExpertCompileLog $ExpertCompileLog `
        -ExpertSyntaxLog $ExpertSyntaxLog `
        -ExpertTarget $ExpertRelativePath `
        -OutputMarkdown $ValidatorOutputMarkdown
    if ($LASTEXITCODE -ne 0) {
        throw "validate_build_gate.ps1 reported failure."
    }
    Write-Output ("Validation markdown written: {0}" -f $ValidatorOutputMarkdown)
}
