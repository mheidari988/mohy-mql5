[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$MqlRoot = "",
    [string]$SourceRelativePath = "Files/MOHY/config",
    [string]$TesterRelativePath = "tester/files/MOHY/config",
    [switch]$IncludeEffective,
    [switch]$KeepExtraFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-PathOrThrow {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("{0} not found at '{1}'." -f $Label, $Path)
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-RelativePathFromBase {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$ChildPath
    )

    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/')
    $childFull = [System.IO.Path]::GetFullPath($ChildPath)
    $baseWithSeparator = $baseFull + "\"
    if ($childFull.StartsWith($baseWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $childFull.Substring($baseWithSeparator.Length)
    }
    return $childFull
}

if ($MqlRoot -eq "") {
    $MqlRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
else {
    $MqlRoot = Resolve-PathOrThrow -Path $MqlRoot -Label "MQL root"
}

$terminalRoot = Split-Path -Parent $MqlRoot
$sourceRoot = Resolve-PathOrThrow -Path (Join-Path $MqlRoot $SourceRelativePath) -Label "Source config directory"
$targetRoot = Join-Path $terminalRoot $TesterRelativePath

$allSourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File)
$sourceFiles = $allSourceFiles
if (-not $IncludeEffective) {
    $sourceFiles = @(
        $allSourceFiles | Where-Object {
            $relativePath = Get-RelativePathFromBase -BasePath $sourceRoot -ChildPath $_.FullName
            -not $relativePath.StartsWith("effective\", [System.StringComparison]::OrdinalIgnoreCase)
        }
    )
}

if (-not $KeepExtraFiles -and (Test-Path -LiteralPath $targetRoot)) {
    if ($PSCmdlet.ShouldProcess($targetRoot, "Remove existing tester config directory")) {
        Remove-Item -LiteralPath $targetRoot -Recurse -Force
    }
}

if (-not (Test-Path -LiteralPath $targetRoot)) {
    if ($PSCmdlet.ShouldProcess($targetRoot, "Create tester config directory")) {
        New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    }
}

$copiedCount = 0
foreach ($sourceFile in $sourceFiles) {
    $relativePath = Get-RelativePathFromBase -BasePath $sourceRoot -ChildPath $sourceFile.FullName
    $destinationPath = Join-Path $targetRoot $relativePath
    $destinationParent = Split-Path -Parent $destinationPath
    if ($destinationParent -and -not (Test-Path -LiteralPath $destinationParent)) {
        if ($PSCmdlet.ShouldProcess($destinationParent, "Create destination directory")) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }
    }

    if ($PSCmdlet.ShouldProcess($destinationPath, ("Copy '{0}'" -f $relativePath))) {
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $destinationPath -Force
        $copiedCount++
    }
}

Write-Output ("Source: {0}" -f $sourceRoot)
Write-Output ("Target: {0}" -f $targetRoot)
Write-Output ("Selected source files: {0}" -f $sourceFiles.Count)
Write-Output ("Copied files: {0}" -f $copiedCount)
Write-Output ("IncludeEffective: {0}" -f [bool]$IncludeEffective)
Write-Output ("KeepExtraFiles: {0}" -f [bool]$KeepExtraFiles)

if ($sourceFiles.Count -eq 0) {
    Write-Warning "No source config files were found. Verify generated files exist under Files/MOHY/config."
}
