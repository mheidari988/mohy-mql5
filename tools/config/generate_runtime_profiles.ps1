[CmdletBinding()]
param(
  [string]$RegistryPath = "config/registry/profiles.json",
  [string]$OutputRoot = "Files/MOHY/config",
  [string]$ManifestPath = "tools/config/manifest.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-ToHashtable {
  param([object]$Value)

  if($null -eq $Value) { return $null }
  if($Value -is [hashtable]) {
    $out = @{}
    foreach($k in $Value.Keys) { $out[$k] = Convert-ToHashtable $Value[$k] }
    return $out
  }
  if($Value -is [pscustomobject]) {
    $out = @{}
    foreach($p in $Value.PSObject.Properties) { $out[$p.Name] = Convert-ToHashtable $p.Value }
    return $out
  }
  if($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
    $items = @()
    foreach($item in $Value) { $items += ,(Convert-ToHashtable $item) }
    return $items
  }
  return $Value
}

function Get-SectionMap {
  param(
    [hashtable]$Root,
    [string]$Name
  )

  if(-not $Root.ContainsKey($Name) -or $null -eq $Root[$Name]) {
    return @{}
  }
  if($Root[$Name] -isnot [hashtable]) {
    throw "Registry section '$Name' must be an object."
  }
  return @{} + $Root[$Name]
}

function Normalize-Scalar {
  param([object]$Value)

  if($Value -is [bool]) {
    return $Value.ToString().ToLowerInvariant()
  }
  if($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
     $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64]) {
    return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0}", $Value)
  }
  if($Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
    return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:0.################}", [double]$Value)
  }
  return [string]$Value
}

function Merge-Maps {
  param(
    [hashtable]$Base,
    [hashtable]$Overrides
  )

  $out = @{} + $Base
  foreach($key in $Overrides.Keys) {
    $out[$key] = $Overrides[$key]
  }
  return $out
}

function Write-IniFile {
  param(
    [string]$Path,
    [hashtable]$Values
  )

  $lines = @()
  foreach($key in ($Values.Keys | Sort-Object)) {
    $lines += ("{0}={1}" -f $key.ToLowerInvariant(), (Normalize-Scalar $Values[$key]))
  }
  Set-Content -Path $Path -Value $lines -Encoding ASCII
}

function Split-IndicatorInputMap {
  param(
    [hashtable]$FlatMap,
    [string]$DefaultIndicator = "MOHY_Visualizer"
  )

  $legacy = @{}
  $scoped = @{}
  foreach($rawKey in $FlatMap.Keys) {
    $value = $FlatMap[$rawKey]
    if($rawKey -match '^(?<indicator>[A-Za-z_][A-Za-z0-9_]*)\.(?<input>[A-Za-z_][A-Za-z0-9_]*)$') {
      $indicator = $Matches["indicator"]
      $input = $Matches["input"]
      if(-not $scoped.ContainsKey($indicator)) {
        $scoped[$indicator] = @{}
      }
      $scoped[$indicator][$input] = $value
      continue
    }

    $legacy[$rawKey] = $value
  }

  if($legacy.Count -gt 0) {
    if(-not $scoped.ContainsKey($DefaultIndicator)) {
      $scoped[$DefaultIndicator] = @{}
    }
    foreach($legacyKey in $legacy.Keys) {
      if(-not $scoped[$DefaultIndicator].ContainsKey($legacyKey)) {
        $scoped[$DefaultIndicator][$legacyKey] = $legacy[$legacyKey]
      }
    }
  }

  return @{
    scoped = $scoped
    legacy = $legacy
  }
}

function Get-Fnv32Hex {
  param([string]$Text)

  [uint32]$hash = 2166136261
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  foreach($b in $bytes) {
    $hash = $hash -bxor [uint32]$b
    $hash = [uint32](([uint64]$hash * [uint64]16777619) % 4294967296)
  }
  return ("{0:X8}" -f $hash)
}

function Get-ConfigHash {
  param([hashtable]$Values)

  $lines = @()
  foreach($key in ($Values.Keys | Sort-Object)) {
    $lines += ("{0}={1}" -f $key.ToLowerInvariant(), (Normalize-Scalar $Values[$key]))
  }
  $canonical = ($lines -join "`n")
  if($canonical -ne "") {
    $canonical += "`n"
  }
  return (Get-Fnv32Hex -Text $canonical)
}

if(-not (Test-Path -Path $RegistryPath)) {
  throw "Registry file not found: $RegistryPath"
}

$registry = Convert-ToHashtable (Get-Content -Path $RegistryPath -Raw | ConvertFrom-Json)
if(-not $registry.ContainsKey("schema_version")) {
  throw "Registry must contain schema_version."
}

$defaultMap = Get-SectionMap -Root $registry -Name "default"
$pairsMap = Get-SectionMap -Root $registry -Name "pairs"
$experimentsMap = Get-SectionMap -Root $registry -Name "experiments"
$indicatorInputsMap = Get-SectionMap -Root $registry -Name "indicator_inputs"
$indicatorMapSplit = Split-IndicatorInputMap -FlatMap $indicatorInputsMap
$indicatorScopedMap = @{} + $indicatorMapSplit.scoped
$indicatorLegacyMap = @{} + $indicatorMapSplit.legacy

foreach($pairKey in $pairsMap.Keys) {
  if($pairsMap[$pairKey] -isnot [hashtable]) {
    throw "pairs.$pairKey must be an object."
  }
}
foreach($expKey in $experimentsMap.Keys) {
  if($experimentsMap[$expKey] -isnot [hashtable]) {
    throw "experiments.$expKey must be an object."
  }
}

$pairsDir = Join-Path $OutputRoot "pairs"
$experimentsDir = Join-Path $OutputRoot "experiments"
$indicatorsDir = Join-Path $OutputRoot "indicators"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
New-Item -ItemType Directory -Force -Path $pairsDir | Out-Null
New-Item -ItemType Directory -Force -Path $experimentsDir | Out-Null
New-Item -ItemType Directory -Force -Path $indicatorsDir | Out-Null

$defaultIni = Join-Path $OutputRoot "default.ini"
Write-IniFile -Path $defaultIni -Values $defaultMap

foreach($pair in ($pairsMap.Keys | Sort-Object)) {
  $pairIni = Join-Path $pairsDir ("{0}.ini" -f $pair)
  Write-IniFile -Path $pairIni -Values $pairsMap[$pair]
}

foreach($exp in ($experimentsMap.Keys | Sort-Object)) {
  $expIni = Join-Path $experimentsDir ("{0}.ini" -f $exp)
  Write-IniFile -Path $expIni -Values $experimentsMap[$exp]
}

$indicatorInputsIni = Join-Path $OutputRoot "indicator_inputs.ini"
foreach($indicator in ($indicatorScopedMap.Keys | Sort-Object)) {
  $indicatorPath = Join-Path $indicatorsDir ("{0}.ini" -f $indicator)
  Write-IniFile -Path $indicatorPath -Values $indicatorScopedMap[$indicator]
}

$legacyCompatMap = @{}
if($indicatorLegacyMap.Count -gt 0) {
  $legacyCompatMap = @{} + $indicatorLegacyMap
} elseif($indicatorScopedMap.ContainsKey("MOHY_Visualizer")) {
  # Backward compatibility path for indicator runtime loaders reading indicator_inputs.ini.
  $legacyCompatMap = @{} + $indicatorScopedMap["MOHY_Visualizer"]
}
Write-IniFile -Path $indicatorInputsIni -Values $legacyCompatMap

$manifestRows = @()
$pairNames = @($pairsMap.Keys | Sort-Object)
if($pairNames.Count -eq 0) {
  $pairNames = @("")
}
$experimentNames = @("") + @($experimentsMap.Keys | Sort-Object)

foreach($pair in $pairNames) {
  $pairOverrides = if($pair -ne "") { @{} + $pairsMap[$pair] } else { @{} }
  foreach($experiment in $experimentNames) {
    $experimentOverrides = if($experiment -ne "") { @{} + $experimentsMap[$experiment] } else { @{} }
    $effective = Merge-Maps -Base $defaultMap -Overrides $pairOverrides
    $effective = Merge-Maps -Base $effective -Overrides $experimentOverrides

    $profileId = if($pair -eq "") { "default" } else { "pair:$pair" }
    if($experiment -ne "") {
      $profileId = "$profileId|exp:$experiment"
    }

    $manifestRows += [PSCustomObject]@{
      profile_id = $profileId
      symbol = $pair
      experiment = $experiment
      config_hash = (Get-ConfigHash -Values $effective)
      generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
  }
}

New-Item -ItemType Directory -Force -Path (Split-Path $ManifestPath -Parent) | Out-Null
$manifestRows | Export-Csv -Path $ManifestPath -NoTypeInformation -Encoding ASCII

Write-Output ("Runtime profiles generated from {0}" -f $RegistryPath)
Write-Output ("Default: {0}" -f $defaultIni)
Write-Output ("Pairs: {0}" -f $pairsDir)
Write-Output ("Experiments: {0}" -f $experimentsDir)
Write-Output ("IndicatorInputsDir: {0}" -f $indicatorsDir)
Write-Output ("IndicatorInputsLegacy: {0}" -f $indicatorInputsIni)
Write-Output ("Manifest: {0}" -f $ManifestPath)
