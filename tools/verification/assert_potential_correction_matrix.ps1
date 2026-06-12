[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MatrixCsv,
    [string]$OutputAssertionsCsv = "docs/verification/potential_correction/artifacts/matrix_assertions.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $MatrixCsv)) {
    throw "Matrix CSV not found: $MatrixCsv"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$outAbs = Join-Path $repoRoot $OutputAssertionsCsv
$outParent = Split-Path -Parent $outAbs
if ($outParent -and -not (Test-Path -LiteralPath $outParent)) {
    New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}

function To-Bool {
    param([object]$Value)
    $text = [string]$Value
    return ($text -eq "1" -or $text -eq "True" -or $text -eq "true")
}

function To-Int {
    param([object]$Value)
    return [int]$Value
}

function To-Double {
    param([object]$Value)
    return [double]$Value
}

function Nearly-Equal {
    param(
        [double]$A,
        [double]$B
    )
    return ([math]::Abs($A - $B) -le 1e-12)
}

$rowsRaw = @(Import-Csv -LiteralPath $MatrixCsv)
if ($rowsRaw.Count -eq 0) {
    throw "Matrix CSV has no data rows: $MatrixCsv"
}

$runId = [string]$rowsRaw[0].run_id

$rows = @(
    $rowsRaw | ForEach-Object {
        [pscustomobject]@{
            case_index                        = To-Int $_.case_index
            enable                            = To-Bool $_.enable
            min_opposite_ici_count            = To-Int $_.min_opposite_ici_count
            min_fib_level                     = To-Int $_.min_fib_level
            min_fib_trigger_mode              = To-Int $_.min_fib_trigger_mode
            max_fib_level                     = To-Int $_.max_fib_level
            max_fib_trigger_mode              = To-Int $_.max_fib_trigger_mode
            extreme_touch_epsilon_points      = To-Double $_.extreme_touch_epsilon_points
            extreme_touch_min_count           = To-Int $_.extreme_touch_min_count
            supersede_direction_mode          = To-Int $_.supersede_direction_mode
            supersede_scope                   = To-Int $_.supersede_scope
            fib_range_valid                   = To-Bool $_.fib_range_valid
            selection_count                   = To-Int $_.selection_count
            confirmed_count                   = To-Int $_.confirmed_count
            invalidated_max_fib_count         = To-Int $_.invalidated_max_fib_count
            invalidated_supersede_count       = To-Int $_.invalidated_supersede_count
            invariant_violation_count         = To-Int $_.invariant_violation_count
            invariant_sample                  = [string]$_.invariant_sample
        }
    }
)

$assertions = New-Object System.Collections.Generic.List[object]

function Add-Assertion {
    param(
        [string]$RuleId,
        [bool]$Pass,
        [int]$ViolationCount,
        [string]$Sample
    )
    $assertions.Add([pscustomobject]@{
        run_id = $runId
        rule_id = $RuleId
        pass = if($Pass){1}else{0}
        violation_count = $ViolationCount
        sample = $Sample
    })
}

$vEnableOff = @($rows | Where-Object { -not $_.enable -and $_.selection_count -ne 0 })
Add-Assertion -RuleId "ENABLE_OFF_EMPTY" `
    -Pass ($vEnableOff.Count -eq 0) `
    -ViolationCount $vEnableOff.Count `
    -Sample ($(if($vEnableOff.Count -gt 0){"case=$($vEnableOff[0].case_index) count=$($vEnableOff[0].selection_count)"}else{""}))

$vInvalidFib = @($rows | Where-Object { -not $_.fib_range_valid -and $_.selection_count -ne 0 })
Add-Assertion -RuleId "INVALID_FIB_RANGE_EMPTY" `
    -Pass ($vInvalidFib.Count -eq 0) `
    -ViolationCount $vInvalidFib.Count `
    -Sample ($(if($vInvalidFib.Count -gt 0){"case=$($vInvalidFib[0].case_index) count=$($vInvalidFib[0].selection_count) minFib=$($vInvalidFib[0].min_fib_level) maxFib=$($vInvalidFib[0].max_fib_level)"}else{""}))

$enabledValid = @($rows | Where-Object { $_.enable -and $_.fib_range_valid })
$vSelectionStable = 0
$sSelectionStable = ""
if ($enabledValid.Count -gt 0) {
    $baseline = $enabledValid[0]
    foreach ($row in $enabledValid) {
        if ($row.selection_count -ne $baseline.selection_count) {
            $vSelectionStable++
            if ($sSelectionStable -eq "") {
                $sSelectionStable = "baseCase=$($baseline.case_index) baseCount=$($baseline.selection_count) compareCase=$($row.case_index) compareCount=$($row.selection_count)"
            }
        }
    }
}
Add-Assertion -RuleId "SELECTION_COUNT_STABLE_WHEN_ENABLED_VALID_FIB" `
    -Pass ($vSelectionStable -eq 0) `
    -ViolationCount $vSelectionStable `
    -Sample $sSelectionStable

$invRows = @($rows | Where-Object { $_.invariant_violation_count -gt 0 })
$invCount = ($invRows | Measure-Object -Property invariant_violation_count -Sum).Sum
if ($null -eq $invCount) { $invCount = 0 }
$invSample = ""
if ($invRows.Count -gt 0) {
    $invSample = "case=$($invRows[0].case_index) violations=$($invRows[0].invariant_violation_count) sample=$($invRows[0].invariant_sample)"
}
Add-Assertion -RuleId "FACT_INVARIANTS" `
    -Pass ($invCount -eq 0) `
    -ViolationCount ([int]$invCount) `
    -Sample $invSample

$rowsForPairs = @($rows | Where-Object { $_.enable -and $_.fib_range_valid })

$vMinOpp = 0
$sMinOpp = ""
$groupMinOpp = $rowsForPairs | Group-Object {
    "minFib=$($_.min_fib_level)|minTrig=$($_.min_fib_trigger_mode)|maxFib=$($_.max_fib_level)|maxTrig=$($_.max_fib_trigger_mode)|eps=$($_.extreme_touch_epsilon_points)|touchMin=$($_.extreme_touch_min_count)|supDir=$($_.supersede_direction_mode)|supScope=$($_.supersede_scope)"
}
foreach ($g in $groupMinOpp) {
    $items = @($g.Group | Sort-Object min_opposite_ici_count, case_index)
    for($i = 0; $i -lt $items.Count; $i++) {
        for($j = $i + 1; $j -lt $items.Count; $j++) {
            if($items[$i].min_opposite_ici_count -lt $items[$j].min_opposite_ici_count -and
               $items[$j].confirmed_count -gt $items[$i].confirmed_count) {
                $vMinOpp++
                if($sMinOpp -eq "") {
                    $sMinOpp = "case$($items[$i].case_index)[minOpp=$($items[$i].min_opposite_ici_count),confirmed=$($items[$i].confirmed_count)] -> case$($items[$j].case_index)[minOpp=$($items[$j].min_opposite_ici_count),confirmed=$($items[$j].confirmed_count)]"
                }
            }
        }
    }
}
Add-Assertion -RuleId "MIN_OPPOSITE_ICI_MONOTONIC_CONFIRMED" -Pass ($vMinOpp -eq 0) -ViolationCount $vMinOpp -Sample $sMinOpp

$TOUCH = 0
$vMinFibTrigger = 0
$sMinFibTrigger = ""
$groupMinTrig = $rowsForPairs | Group-Object {
    "minOpp=$($_.min_opposite_ici_count)|minFib=$($_.min_fib_level)|maxFib=$($_.max_fib_level)|maxTrig=$($_.max_fib_trigger_mode)|eps=$($_.extreme_touch_epsilon_points)|touchMin=$($_.extreme_touch_min_count)|supDir=$($_.supersede_direction_mode)|supScope=$($_.supersede_scope)"
}
foreach($g in $groupMinTrig) {
    $touch = @($g.Group | Where-Object { $_.min_fib_trigger_mode -eq $TOUCH } | Select-Object -First 1)
    $close = @($g.Group | Where-Object { $_.min_fib_trigger_mode -ne $TOUCH } | Select-Object -First 1)
    if($touch.Count -gt 0 -and $close.Count -gt 0 -and $close[0].confirmed_count -gt $touch[0].confirmed_count) {
        $vMinFibTrigger++
        if($sMinFibTrigger -eq "") {
            $sMinFibTrigger = "touchCase=$($touch[0].case_index) closeCase=$($close[0].case_index) touchConfirmed=$($touch[0].confirmed_count) closeConfirmed=$($close[0].confirmed_count)"
        }
    }
}
Add-Assertion -RuleId "MIN_FIB_CLOSE_STRICTER_THAN_TOUCH" -Pass ($vMinFibTrigger -eq 0) -ViolationCount $vMinFibTrigger -Sample $sMinFibTrigger

$vMaxFibTrigger = 0
$sMaxFibTrigger = ""
$groupMaxTrig = $rowsForPairs | Group-Object {
    "minOpp=$($_.min_opposite_ici_count)|minFib=$($_.min_fib_level)|minTrig=$($_.min_fib_trigger_mode)|maxFib=$($_.max_fib_level)|eps=$($_.extreme_touch_epsilon_points)|touchMin=$($_.extreme_touch_min_count)|supDir=$($_.supersede_direction_mode)|supScope=$($_.supersede_scope)"
}
foreach($g in $groupMaxTrig) {
    $touch = @($g.Group | Where-Object { $_.max_fib_trigger_mode -eq $TOUCH } | Select-Object -First 1)
    $close = @($g.Group | Where-Object { $_.max_fib_trigger_mode -ne $TOUCH } | Select-Object -First 1)
    if($touch.Count -gt 0 -and $close.Count -gt 0 -and $close[0].invalidated_max_fib_count -gt $touch[0].invalidated_max_fib_count) {
        $vMaxFibTrigger++
        if($sMaxFibTrigger -eq "") {
            $sMaxFibTrigger = "touchCase=$($touch[0].case_index) closeCase=$($close[0].case_index) touchMaxInv=$($touch[0].invalidated_max_fib_count) closeMaxInv=$($close[0].invalidated_max_fib_count)"
        }
    }
}
Add-Assertion -RuleId "MAX_FIB_CLOSE_LOOSER_THAN_TOUCH" -Pass ($vMaxFibTrigger -eq 0) -ViolationCount $vMaxFibTrigger -Sample $sMaxFibTrigger

$SUPERSEDE_ANY = 0
$vSupDir = 0
$sSupDir = ""
$groupSupDir = $rowsForPairs | Group-Object {
    "minOpp=$($_.min_opposite_ici_count)|minFib=$($_.min_fib_level)|minTrig=$($_.min_fib_trigger_mode)|maxFib=$($_.max_fib_level)|maxTrig=$($_.max_fib_trigger_mode)|eps=$($_.extreme_touch_epsilon_points)|touchMin=$($_.extreme_touch_min_count)|supScope=$($_.supersede_scope)"
}
foreach($g in $groupSupDir) {
    $any = @($g.Group | Where-Object { $_.supersede_direction_mode -eq $SUPERSEDE_ANY } | Select-Object -First 1)
    $opp = @($g.Group | Where-Object { $_.supersede_direction_mode -ne $SUPERSEDE_ANY } | Select-Object -First 1)
    if($any.Count -gt 0 -and $opp.Count -gt 0 -and $any[0].invalidated_supersede_count -lt $opp[0].invalidated_supersede_count) {
        $vSupDir++
        if($sSupDir -eq "") {
            $sSupDir = "anyCase=$($any[0].case_index) oppCase=$($opp[0].case_index) anySup=$($any[0].invalidated_supersede_count) oppSup=$($opp[0].invalidated_supersede_count)"
        }
    }
}
Add-Assertion -RuleId "SUPERSEDE_DIRECTION_ANY_SUPERSET" -Pass ($vSupDir -eq 0) -ViolationCount $vSupDir -Sample $sSupDir

$SCOPE_FORMING_ONLY = 0
$vSupScope = 0
$sSupScope = ""
$groupSupScope = $rowsForPairs | Group-Object {
    "minOpp=$($_.min_opposite_ici_count)|minFib=$($_.min_fib_level)|minTrig=$($_.min_fib_trigger_mode)|maxFib=$($_.max_fib_level)|maxTrig=$($_.max_fib_trigger_mode)|eps=$($_.extreme_touch_epsilon_points)|touchMin=$($_.extreme_touch_min_count)|supDir=$($_.supersede_direction_mode)"
}
foreach($g in $groupSupScope) {
    $formingOnly = @($g.Group | Where-Object { $_.supersede_scope -eq $SCOPE_FORMING_ONLY } | Select-Object -First 1)
    $formingAnd = @($g.Group | Where-Object { $_.supersede_scope -ne $SCOPE_FORMING_ONLY } | Select-Object -First 1)
    if($formingOnly.Count -gt 0 -and $formingAnd.Count -gt 0 -and $formingAnd[0].invalidated_supersede_count -lt $formingOnly[0].invalidated_supersede_count) {
        $vSupScope++
        if($sSupScope -eq "") {
            $sSupScope = "formingOnlyCase=$($formingOnly[0].case_index) formingAndCase=$($formingAnd[0].case_index) formingOnlySup=$($formingOnly[0].invalidated_supersede_count) formingAndSup=$($formingAnd[0].invalidated_supersede_count)"
        }
    }
}
Add-Assertion -RuleId "SUPERSEDE_SCOPE_FORMING_AND_CONFIRMED_SUPERSET" -Pass ($vSupScope -eq 0) -ViolationCount $vSupScope -Sample $sSupScope

$assertions | Export-Csv -LiteralPath $outAbs -NoTypeInformation -Encoding UTF8

$failCount = @($assertions | Where-Object { $_.pass -eq 0 }).Count
Write-Output ("Assertions CSV: {0}" -f $OutputAssertionsCsv)
Write-Output ("Rules: {0}, Failures: {1}" -f $assertions.Count, $failCount)
foreach($a in $assertions) {
    Write-Output ("{0} pass={1} violations={2}" -f $a.rule_id, $(if($a.pass -eq 1){"true"}else{"false"}), $a.violation_count)
}

if($failCount -gt 0) {
    exit 1
}
