[CmdletBinding()]
param(
  [string]$RegistryPath = "config/registry/profiles.json",
  [string]$TemplateSetPath = "Presets/MOHY_Visualizer.set",
  [string]$OutputRoot = "Presets/MOHY"
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
  param([hashtable]$Root, [string]$Name)
  if(-not $Root.ContainsKey($Name) -or $null -eq $Root[$Name]) { return @{} }
  if($Root[$Name] -isnot [hashtable]) { throw "Registry section '$Name' must be an object." }
  return @{} + $Root[$Name]
}

function Sanitize-Token {
  param([string]$Value)
  if([string]::IsNullOrWhiteSpace($Value)) { return "DEFAULT" }
  return ([regex]::Replace($Value, '[^A-Za-z0-9_-]', '_'))
}

if(-not (Test-Path -Path $RegistryPath)) {
  throw "Registry file not found: $RegistryPath"
}
if(-not (Test-Path -Path $TemplateSetPath)) {
  throw "Template set file not found: $TemplateSetPath"
}

$registry = Convert-ToHashtable (Get-Content -Path $RegistryPath -Raw | ConvertFrom-Json)
$pairsMap = Get-SectionMap -Root $registry -Name "pairs"
$experimentsMap = Get-SectionMap -Root $registry -Name "experiments"
$templateLines = Get-Content -Path $TemplateSetPath

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$pairNames = @($pairsMap.Keys | Sort-Object)
if($pairNames.Count -eq 0) { $pairNames = @("") }
$experimentNames = @("") + @($experimentsMap.Keys | Sort-Object)

$generated = 0
foreach($pair in $pairNames) {
  foreach($experiment in $experimentNames) {
    $pairToken = Sanitize-Token -Value $pair
    $expToken = if([string]::IsNullOrWhiteSpace($experiment)) { "" } else { "__" + (Sanitize-Token -Value $experiment) }
    $fileName = "{0}{1}.set" -f $pairToken, $expToken
    $path = Join-Path $OutputRoot $fileName
    Set-Content -Path $path -Value $templateLines -Encoding ASCII
    $generated++
  }
}

Write-Output ("Generated {0} visualizer set files in {1}" -f $generated, $OutputRoot)
Write-Output ("Template source: {0}" -f $TemplateSetPath)
