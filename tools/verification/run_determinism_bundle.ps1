[CmdletBinding()]
param(
    [string]$MetaEditorPath = "C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe",
    [string]$MqlRoot = "",
    [string]$VerificationFilesRoot = "Files/MOHY/verification",
    [string]$KernelAssertionsCsv = "",
    [string]$ImpulseAssertionsCsv = "",
    [string]$CorrectionAssertionsCsv = "",
    [string]$OutputMarkdown = "docs/verification/determinism/artifacts/determinism_bundle_summary.md",
    [switch]$SkipCompile,
    [switch]$SkipSyntax,
    [switch]$RequireAssertions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($MqlRoot -eq "") {
    $MqlRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
else {
    $MqlRoot = (Resolve-Path $MqlRoot).Path
}

$outputAbs = Join-Path $MqlRoot $OutputMarkdown
$outputParent = Split-Path -Parent $outputAbs
if ($outputParent -and -not (Test-Path -LiteralPath $outputParent)) {
    New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
}

$artifactRootAbs = Join-Path $MqlRoot "docs/verification/determinism/artifacts"
if (-not (Test-Path -LiteralPath $artifactRootAbs)) {
    New-Item -ItemType Directory -Path $artifactRootAbs -Force | Out-Null
}

if ((-not $SkipCompile -or -not $SkipSyntax) -and -not (Test-Path -LiteralPath $MetaEditorPath)) {
    throw "MetaEditor not found at '$MetaEditorPath'."
}

function Invoke-MetaEditorPass {
    param(
        [Parameter(Mandatory = $true)][string]$SourceAbsPath,
        [Parameter(Mandatory = $true)][string]$LogAbsPath,
        [Parameter(Mandatory = $true)][bool]$SyntaxOnly
    )

    $args = @(
        "/compile:$SourceAbsPath",
        "/include:$MqlRoot",
        "/log:$LogAbsPath"
    )
    if ($SyntaxOnly) {
        $args += "/s"
    }

    $proc = Start-Process -FilePath $MetaEditorPath -ArgumentList $args -Wait -PassThru
    return ($proc.ExitCode -eq 0)
}

function Read-CompileResultLine {
    param([string]$LogAbsPath)
    if (-not (Test-Path -LiteralPath $LogAbsPath)) {
        return ""
    }
    $line = Select-String -LiteralPath $LogAbsPath -Pattern "^Result:" | Select-Object -Last 1
    if ($null -eq $line) {
        return ""
    }
    return [string]$line.Line.Trim()
}

function Read-SyntaxResultLine {
    param([string]$LogAbsPath)
    if (-not (Test-Path -LiteralPath $LogAbsPath)) {
        return ""
    }
    $line = Select-String -LiteralPath $LogAbsPath -Pattern "result [0-9]+ errors" | Select-Object -Last 1
    if ($null -eq $line) {
        return ""
    }
    return [string]$line.Line.Trim()
}

function Test-CompileResultLine {
    param([string]$Line)
    return ($Line -match "^Result:\s+0 errors,")
}

function Test-SyntaxResultLine {
    param([string]$Line)
    return ($Line -match "result\s+0 errors,")
}

function Resolve-AssertionsCsv {
    param(
        [string]$ManualPath,
        [string]$DirectoryAbsPath
    )

    if ($ManualPath -ne "") {
        $candidate = if ([System.IO.Path]::IsPathRooted($ManualPath)) { $ManualPath } else { Join-Path $MqlRoot $ManualPath }
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
        return ""
    }

    if (-not (Test-Path -LiteralPath $DirectoryAbsPath)) {
        return ""
    }

    $latest = Get-ChildItem -LiteralPath $DirectoryAbsPath -Filter "*__assertions.csv" -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -eq $latest) {
        return ""
    }
    return $latest.FullName
}

function Measure-Assertions {
    param([string]$CsvAbsPath)

    if ($CsvAbsPath -eq "" -or -not (Test-Path -LiteralPath $CsvAbsPath)) {
        return [pscustomobject]@{
            Path = $CsvAbsPath
            Exists = $false
            Total = 0
            Pass = 0
            Fail = 0
            FailRules = @()
            ParseError = ""
        }
    }

    try {
        $rows = @(Import-Csv -LiteralPath $CsvAbsPath)
        $passRows = @($rows | Where-Object { [string]$_.pass -eq "1" -or [string]$_.pass -eq "True" })
        $failRows = @($rows | Where-Object { [string]$_.pass -eq "0" -or [string]$_.pass -eq "False" })
        return [pscustomobject]@{
            Path = $CsvAbsPath
            Exists = $true
            Total = $rows.Count
            Pass = $passRows.Count
            Fail = $failRows.Count
            FailRules = @($failRows | ForEach-Object { [string]$_.rule_id })
            ParseError = ""
        }
    }
    catch {
        return [pscustomobject]@{
            Path = $CsvAbsPath
            Exists = $true
            Total = 0
            Pass = 0
            Fail = 0
            FailRules = @()
            ParseError = $_.Exception.Message
        }
    }
}

function To-DisplayPath {
    param([string]$PathValue)
    if ($PathValue -eq "") {
        return ""
    }

    $rootNorm = [System.IO.Path]::GetFullPath($MqlRoot).TrimEnd('\')
    $pathNorm = [System.IO.Path]::GetFullPath($PathValue)
    if ($pathNorm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        $trimmed = $pathNorm.Substring($rootNorm.Length)
        if ($trimmed.StartsWith("\") -or $trimmed.StartsWith("/")) {
            $trimmed = $trimmed.Substring(1)
        }
        return $trimmed
    }
    return $pathNorm
}

$targets = @(
    [pscustomobject]@{
        Name = "KernelSnapshotDeterminismVerifier"
        SourceRel = "Scripts/MOHY/KernelSnapshotDeterminismVerifier.mq5"
        AssertionDirRel = "kernel_snapshot"
        ManualAssertionPath = $KernelAssertionsCsv
    },
    [pscustomobject]@{
        Name = "PotentialImpulseMatrixVerifier"
        SourceRel = "Scripts/MOHY/PotentialImpulseMatrixVerifier.mq5"
        AssertionDirRel = "potential_impulse"
        ManualAssertionPath = $ImpulseAssertionsCsv
    },
    [pscustomobject]@{
        Name = "PotentialCorrectionMatrixVerifier"
        SourceRel = "Scripts/MOHY/PotentialCorrectionMatrixVerifier.mq5"
        AssertionDirRel = "potential_correction"
        ManualAssertionPath = $CorrectionAssertionsCsv
    }
)

$rows = @()
$overallCompileFail = 0
$overallSyntaxFail = 0
$overallAssertionFail = 0
$overallAssertionMissing = 0
$overallParseFail = 0

foreach ($t in $targets) {
    $sourceAbs = Join-Path $MqlRoot $t.SourceRel
    if (-not (Test-Path -LiteralPath $sourceAbs)) {
        throw "Source file not found: $($t.SourceRel)"
    }

    $compileLogAbs = Join-Path $artifactRootAbs ("compile_{0}.log" -f $t.Name)
    $syntaxLogAbs = Join-Path $artifactRootAbs ("syntax_{0}.log" -f $t.Name)

    $compileStatus = "SKIPPED"
    $syntaxStatus = "SKIPPED"

    if (-not $SkipCompile) {
        $null = Invoke-MetaEditorPass -SourceAbsPath $sourceAbs -LogAbsPath $compileLogAbs -SyntaxOnly:$false
        $compileResultLine = Read-CompileResultLine -LogAbsPath $compileLogAbs
        $compileOk = Test-CompileResultLine -Line $compileResultLine
        $compileStatus = if ($compileOk) { "PASS" } else { "FAIL" }
        if (-not $compileOk) { $overallCompileFail++ }
    }

    if (-not $SkipSyntax) {
        $null = Invoke-MetaEditorPass -SourceAbsPath $sourceAbs -LogAbsPath $syntaxLogAbs -SyntaxOnly:$true
        $syntaxResultLine = Read-SyntaxResultLine -LogAbsPath $syntaxLogAbs
        $syntaxOk = Test-SyntaxResultLine -Line $syntaxResultLine
        $syntaxStatus = if ($syntaxOk) { "PASS" } else { "FAIL" }
        if (-not $syntaxOk) { $overallSyntaxFail++ }
    }

    $assertionDirAbs = Join-Path (Join-Path $MqlRoot $VerificationFilesRoot) $t.AssertionDirRel
    $assertionsCsvAbs = Resolve-AssertionsCsv -ManualPath $t.ManualAssertionPath -DirectoryAbsPath $assertionDirAbs
    $assertionStats = Measure-Assertions -CsvAbsPath $assertionsCsvAbs

    $assertionStatus = "MISSING"
    if ($assertionStats.Exists) {
        if ($assertionStats.ParseError -ne "") {
            $assertionStatus = "PARSE_FAIL"
            $overallParseFail++
        }
        elseif ($assertionStats.Fail -gt 0) {
            $assertionStatus = "FAIL"
            $overallAssertionFail++
        }
        else {
            $assertionStatus = "PASS"
        }
    }
    else {
        $overallAssertionMissing++
    }

    $rows += [pscustomobject]@{
        Name = $t.Name
        SourceRel = $t.SourceRel
        CompileStatus = $compileStatus
        CompileResult = Read-CompileResultLine -LogAbsPath $compileLogAbs
        CompileLogRel = To-DisplayPath -PathValue $compileLogAbs
        SyntaxStatus = $syntaxStatus
        SyntaxResult = Read-SyntaxResultLine -LogAbsPath $syntaxLogAbs
        SyntaxLogRel = To-DisplayPath -PathValue $syntaxLogAbs
        AssertionStatus = $assertionStatus
        AssertionCsvRel = if ($assertionStats.Exists) { To-DisplayPath -PathValue $assertionStats.Path } else { "" }
        AssertionTotal = $assertionStats.Total
        AssertionPass = $assertionStats.Pass
        AssertionFail = $assertionStats.Fail
        AssertionFailRules = if ($assertionStats.FailRules.Count -gt 0) { ($assertionStats.FailRules -join ", ") } else { "" }
        AssertionParseError = $assertionStats.ParseError
    }
}

$overall = "PASS"
if ($overallCompileFail -gt 0 -or $overallSyntaxFail -gt 0 -or $overallAssertionFail -gt 0 -or $overallParseFail -gt 0) {
    $overall = "FAIL"
}
elseif ($RequireAssertions -and $overallAssertionMissing -gt 0) {
    $overall = "FAIL"
}

$lines = @()
$lines += "# Determinism Bundle Summary"
$lines += ""
$lines += "- Captured UTC: $((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))"
$lines += "- Overall: $overall"
$lines += "- Compile failures: $overallCompileFail"
$lines += "- Syntax failures: $overallSyntaxFail"
$lines += "- Assertion failures: $overallAssertionFail"
$lines += "- Assertion parse failures: $overallParseFail"
$lines += "- Assertion CSV missing: $overallAssertionMissing"
$lines += "- Require assertions: $($RequireAssertions.IsPresent)"
$lines += ""
$lines += "## Per Verifier"
$lines += ""
$lines += "| Verifier | Compile | Syntax | Assertions | Pass/Total | Assertion CSV |"
$lines += "|---|---|---|---|---:|---|"
foreach ($r in $rows) {
    $ratio = "{0}/{1}" -f $r.AssertionPass, $r.AssertionTotal
    $csvText = if ($r.AssertionCsvRel -ne "") { $r.AssertionCsvRel } else { "-" }
    $lines += "| $($r.Name) | $($r.CompileStatus) | $($r.SyntaxStatus) | $($r.AssertionStatus) | $ratio | $csvText |"
}
$lines += ""
$lines += "## Details"
$lines += ""
foreach ($r in $rows) {
    $lines += "### $($r.Name)"
    $lines += "- Source: $($r.SourceRel)"
    $lines += "- Compile: $($r.CompileStatus)"
    $lines += "- Compile result: $($r.CompileResult)"
    $lines += "- Compile log: $($r.CompileLogRel)"
    $lines += "- Syntax: $($r.SyntaxStatus)"
    $lines += "- Syntax result: $($r.SyntaxResult)"
    $lines += "- Syntax log: $($r.SyntaxLogRel)"
    $lines += "- Assertions: $($r.AssertionStatus) ($($r.AssertionPass)/$($r.AssertionTotal) pass)"
    $lines += "- Assertions CSV: $(if($r.AssertionCsvRel -ne ''){$r.AssertionCsvRel}else{'-'})"
    if ($r.AssertionFailRules -ne "") {
        $lines += "- Failing rules: $($r.AssertionFailRules)"
    }
    if ($r.AssertionParseError -ne "") {
        $lines += "- Parse error: $($r.AssertionParseError)"
    }
    $lines += ""
}

Set-Content -LiteralPath $outputAbs -Value ($lines -join "`n") -Encoding UTF8
Write-Output ("Determinism summary written: {0}" -f $OutputMarkdown)
$rows | ForEach-Object {
    Write-Output ("{0}: compile={1}, syntax={2}, assertions={3} ({4}/{5})" -f $_.Name, $_.CompileStatus, $_.SyntaxStatus, $_.AssertionStatus, $_.AssertionPass, $_.AssertionTotal)
}

if ($overall -ne "PASS") {
    exit 1
}
