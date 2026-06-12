[CmdletBinding()]
param(
    [string]$ArtifactRoot = "Files/MOHY/runtime/portfolio",
    [string]$LiveSnapshotSchema = "playground/schemas/tradeea_live_snapshot_v1.schema.json",
    [string]$PortfolioStateSchema = "playground/schemas/tradeea_portfolio_state_v1.schema.json",
    [string]$OutputMarkdown = "docs/verification/mt5_migration/artifacts/tradeea_artifact_bus_validation.md",
    [datetime]$MinLastWriteTime = [datetime]::MinValue,
    [switch]$RequireFreshArtifacts,
    [switch]$RequireEnrichedFields
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $repoRoot $Path
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$errors = New-Object 'System.Collections.Generic.List[string]'
$notes = New-Object 'System.Collections.Generic.List[string]'

function Add-ValidationError {
    param([Parameter(Mandatory = $true)][string]$Message)

    $script:errors.Add($Message) | Out-Null
}

function Test-Properties {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $actualNames = @($Object.PSObject.Properties.Name)
    foreach ($name in $Names) {
        if ($actualNames -notcontains $name) {
            Add-ValidationError "$Context missing '$name'."
        }
    }
}

function Test-NonEmptyString {
    param(
        [object]$Value,
        [string]$Context
    )

    if ([string]::IsNullOrWhiteSpace([string]$Value)) {
        Add-ValidationError "$Context is empty."
    }
}

function Test-NumberLike {
    param(
        [object]$Value,
        [string]$Context
    )

    if ($null -eq $Value -or -not ($Value -is [ValueType])) {
        Add-ValidationError "$Context is not numeric."
    }
}

$liveSchemaPath = Resolve-RepoPath $LiveSnapshotSchema
$portfolioSchemaPath = Resolve-RepoPath $PortfolioStateSchema
$artifactRootPath = Resolve-RepoPath $ArtifactRoot
$outputPath = Resolve-RepoPath $OutputMarkdown

$selectedPlanEnrichedFields = @(
    "setup_key",
    "impulse_id",
    "direction",
    "execution_mode",
    "setup_time",
    "entry_price",
    "expected_fill_price",
    "required_entry_price",
    "trigger_price",
    "stop_price",
    "target_price",
    "lots_normalized"
)
$portfolioSymbolEnrichedFields = @(
    "selected_setup_key",
    "selected_impulse_id",
    "selected_entry_price",
    "selected_stop_price",
    "selected_target_price"
)
$topRankedEnrichedFields = @("setup_key")

try {
    $liveSchema = Read-JsonFile -Path $liveSchemaPath
    $portfolioSchema = Read-JsonFile -Path $portfolioSchemaPath

    Test-Properties -Object $liveSchema.properties.selected_plan.properties `
        -Names $selectedPlanEnrichedFields `
        -Context "$LiveSnapshotSchema selected_plan schema"
    Test-Properties -Object $portfolioSchema.properties.symbols.items.properties `
        -Names $portfolioSymbolEnrichedFields `
        -Context "$PortfolioStateSchema symbols item schema"
    Test-Properties -Object $portfolioSchema.properties.top_ranked.items.properties `
        -Names $topRankedEnrichedFields `
        -Context "$PortfolioStateSchema top_ranked item schema"
} catch {
    Add-ValidationError "Schema parse/declaration failure: $($_.Exception.Message)"
}

$portfolioFiles = @()
$liveFiles = @()
if (Test-Path -LiteralPath $artifactRootPath) {
    $portfolioFiles = @(Get-ChildItem -LiteralPath $artifactRootPath -Recurse -Filter "portfolio_state.json" -File |
        Where-Object { $_.LastWriteTime -ge $MinLastWriteTime } |
        Sort-Object FullName)
    $liveFiles = @(Get-ChildItem -LiteralPath $artifactRootPath -Recurse -Filter "live_snapshot_*.json" -File |
        Where-Object { $_.LastWriteTime -ge $MinLastWriteTime } |
        Sort-Object FullName)
} else {
    Add-ValidationError "Artifact root not found: $ArtifactRoot"
}

if ($RequireFreshArtifacts -and ($portfolioFiles.Count -eq 0 -or $liveFiles.Count -eq 0)) {
    Add-ValidationError "Fresh TradeEA artifact set missing under $ArtifactRoot."
}

foreach ($file in $portfolioFiles) {
    try {
        $json = Read-JsonFile -Path $file.FullName
        if ([string]$json.schema_version -ne "tradeea_portfolio_state_v1") {
            Add-ValidationError "$($file.FullName): invalid schema_version '$($json.schema_version)'."
        }
        if ([string]$json.artifact_type -ne "portfolio_state") {
            Add-ValidationError "$($file.FullName): invalid artifact_type '$($json.artifact_type)'."
        }
        Test-NonEmptyString -Value $json.run_id -Context "$($file.FullName): run_id"
        Test-NonEmptyString -Value $json.scope_tag -Context "$($file.FullName): scope_tag"
        Test-NonEmptyString -Value $json.config_hash -Context "$($file.FullName): config_hash"

        if ($null -eq $json.symbols) {
            Add-ValidationError "$($file.FullName): symbols array missing."
        } elseif ($RequireEnrichedFields) {
            foreach ($symbolRow in @($json.symbols)) {
                Test-Properties -Object $symbolRow -Names $portfolioSymbolEnrichedFields -Context "$($file.FullName): symbols[]"
                Test-NumberLike -Value $symbolRow.selected_entry_price -Context "$($file.FullName): selected_entry_price"
                Test-NumberLike -Value $symbolRow.selected_stop_price -Context "$($file.FullName): selected_stop_price"
                Test-NumberLike -Value $symbolRow.selected_target_price -Context "$($file.FullName): selected_target_price"
            }
        }

        if ($RequireEnrichedFields) {
            foreach ($rankRow in @($json.top_ranked)) {
                Test-Properties -Object $rankRow -Names $topRankedEnrichedFields -Context "$($file.FullName): top_ranked[]"
            }
        }
    } catch {
        Add-ValidationError "$($file.FullName): JSON parse/validation failure: $($_.Exception.Message)"
    }
}

foreach ($file in $liveFiles) {
    try {
        $json = Read-JsonFile -Path $file.FullName
        if ([string]$json.schema_version -ne "tradeea_live_snapshot_v1") {
            Add-ValidationError "$($file.FullName): invalid schema_version '$($json.schema_version)'."
        }
        if ([string]$json.artifact_type -ne "live_snapshot") {
            Add-ValidationError "$($file.FullName): invalid artifact_type '$($json.artifact_type)'."
        }
        Test-NonEmptyString -Value $json.run_id -Context "$($file.FullName): run_id"
        Test-NonEmptyString -Value $json.scope_tag -Context "$($file.FullName): scope_tag"
        Test-NonEmptyString -Value $json.symbol -Context "$($file.FullName): symbol"

        if ($null -eq $json.selected_plan) {
            Add-ValidationError "$($file.FullName): selected_plan missing."
        } elseif ($RequireEnrichedFields) {
            Test-Properties -Object $json.selected_plan -Names $selectedPlanEnrichedFields -Context "$($file.FullName): selected_plan"
            Test-NumberLike -Value $json.selected_plan.entry_price -Context "$($file.FullName): selected_plan.entry_price"
            Test-NumberLike -Value $json.selected_plan.stop_price -Context "$($file.FullName): selected_plan.stop_price"
            Test-NumberLike -Value $json.selected_plan.target_price -Context "$($file.FullName): selected_plan.target_price"
        }
    } catch {
        Add-ValidationError "$($file.FullName): JSON parse/validation failure: $($_.Exception.Message)"
    }
}

if ($portfolioFiles.Count -eq 0 -and $liveFiles.Count -eq 0) {
    $notes.Add("No runtime artifacts found for data validation; schema declarations were still checked.") | Out-Null
}
if (-not $RequireEnrichedFields) {
    $notes.Add("Runtime artifacts were validated in backward-compatible mode; use -RequireEnrichedFields after a fresh TradeEA run.") | Out-Null
}

$overallPass = ($errors.Count -eq 0)
$parent = Split-Path -Path $outputPath -Parent
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$lines = @()
$lines += "# TradeEA Artifact Bus Validation"
$lines += ""
$lines += "- Artifact root: $ArtifactRoot"
$lines += "- Live schema: $LiveSnapshotSchema"
$lines += "- Portfolio schema: $PortfolioStateSchema"
$lines += "- Portfolio files checked: $($portfolioFiles.Count)"
$lines += "- Live snapshot files checked: $($liveFiles.Count)"
$lines += "- Require enriched fields: $(if ($RequireEnrichedFields) { 'YES' } else { 'NO' })"
$lines += "- Overall: $(if ($overallPass) { 'PASS' } else { 'FAIL' })"
$lines += ""
if ($notes.Count -gt 0) {
    $lines += "## Notes"
    foreach ($note in $notes) {
        $lines += "- $note"
    }
    $lines += ""
}
$lines += "## Errors"
if ($errors.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($errorMessage in $errors) {
        $lines += "- $errorMessage"
    }
}

Set-Content -LiteralPath $outputPath -Value ($lines -join "`n") -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }

if (-not $overallPass) {
    exit 1
}
