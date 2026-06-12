[CmdletBinding()]
param(
    [string]$AuditRoot = "Files/MOHY/runtime",
    [string[]]$AuditFiles = @(),
    [string]$OutputMarkdown = "docs/verification/2026-03-phase5/artifacts/non_backtest/audit_validation.md",
    [datetime]$MinLastWriteTime = [datetime]::MinValue,
    [switch]$RequireDangerousChainEvidence
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExpectedHeader = "schema_version,sequence_no,timestamp,chart_id,symbol,scope_tag,config_hash,stage,action_id,correlation_id,pre_state_hash,post_state_hash,result_code,severity,broker_error,message,source"
$AllowedStages = @("Intent", "Confirmed", "Expired", "Outcome")
$AllowedResultCodes = @(
    "Success",
    "BlockedByGuard",
    "DeniedByAuthority",
    "CooldownActive",
    "ConfirmationExpired",
    "BrokerReject",
    "Retrying",
    "FallbackExecuted",
    "Failed"
)
$AllowedSeverities = @("Info", "Warning", "Critical")
$DangerousActionIds = @("CancelWaitingEntries", "CloseStrategyTrades", "EmergencyFlatten")
$ImmediateDangerousResultCodes = @("BlockedByGuard", "CooldownActive")

$errors = New-Object 'System.Collections.Generic.List[string]'
$fileSummaries = New-Object 'System.Collections.Generic.List[object]'
$targetFiles = New-Object 'System.Collections.Generic.List[string]'
$totalRows = 0
$totalCorrelations = 0
$dangerousConfirmedChains = 0

function Add-ValidationError {
    param(
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:errors.Add($Message) | Out-Null
}

function To-Status([bool]$Pass) {
    if ($Pass) { return "PASS" }
    return "FAIL"
}

function Parse-AuditTimestamp {
    param(
        [Parameter(Mandatory = $true)][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [datetime]::MinValue
    }

    $unixSeconds = 0L
    if ([long]::TryParse($Value, [ref]$unixSeconds) -and $unixSeconds -gt 0) {
        try {
            return [DateTimeOffset]::FromUnixTimeSeconds($unixSeconds).UtcDateTime
        } catch {
            return [datetime]::MinValue
        }
    }

    $dt = [datetime]::MinValue
    if ([datetime]::TryParse($Value, [ref]$dt)) {
        return $dt
    }

    return [datetime]::MinValue
}

function Get-GroupStageRows {
    param(
        [Parameter(Mandatory = $true)][object[]]$Rows,
        [Parameter(Mandatory = $true)][string]$Stage
    )

    return ,@($Rows | Where-Object { [string]$_.stage -eq $Stage })
}

if ($AuditFiles.Count -gt 0) {
    foreach ($auditFile in $AuditFiles) {
        if (-not (Test-Path -LiteralPath $auditFile)) {
            Add-ValidationError "Audit file missing: $auditFile"
            continue
        }

        $resolved = (Resolve-Path -LiteralPath $auditFile).Path
        $item = Get-Item -LiteralPath $resolved
        if ($item.LastWriteTime -ge $MinLastWriteTime) {
            $targetFiles.Add($resolved) | Out-Null
        }
    }
} else {
    if (-not (Test-Path -LiteralPath $AuditRoot)) {
        Add-ValidationError "Audit root missing: $AuditRoot"
    } else {
        $found = Get-ChildItem -LiteralPath $AuditRoot -Recurse -Filter "ui_audit.csv" -File |
            Where-Object { $_.LastWriteTime -ge $MinLastWriteTime } |
            Sort-Object FullName
        foreach ($item in $found) {
            $targetFiles.Add($item.FullName) | Out-Null
        }
    }
}

if ($targetFiles.Count -eq 0) {
    Add-ValidationError "No ui_audit.csv files found for validation."
}

foreach ($filePath in ($targetFiles | Sort-Object)) {
    $errorsBefore = $errors.Count

    $header = Get-Content -LiteralPath $filePath -TotalCount 1
    if ([string]::IsNullOrWhiteSpace($header)) {
        Add-ValidationError "${filePath}: Empty file."
        continue
    }

    if ($header.Trim() -ne $ExpectedHeader) {
        Add-ValidationError "${filePath}: Header mismatch. Expected '$ExpectedHeader'."
    }

    try {
        $rows = @(Import-Csv -LiteralPath $filePath)
    } catch {
        Add-ValidationError "${filePath}: CSV parse error: $($_.Exception.Message)"
        continue
    }

    if ($rows.Count -eq 0) {
        Add-ValidationError "${filePath}: No audit rows found."
        continue
    }

    $totalRows += $rows.Count

    $previousSeq = [long]::MinValue
    foreach ($row in $rows) {
        if ([string]$row.schema_version -ne "phase5") {
            Add-ValidationError "${filePath}: Invalid schema_version '$($row.schema_version)'."
        }
        if ([string]::IsNullOrWhiteSpace([string]$row.scope_tag)) {
            Add-ValidationError "${filePath}: scope_tag is empty."
        }
        if ([string]::IsNullOrWhiteSpace([string]$row.config_hash)) {
            Add-ValidationError "${filePath}: config_hash is empty."
        }
        if ([string]::IsNullOrWhiteSpace([string]$row.symbol)) {
            Add-ValidationError "${filePath}: symbol is empty."
        }
        if ([string]::IsNullOrWhiteSpace([string]$row.source)) {
            Add-ValidationError "${filePath}: source is empty."
        }
        if ([string]::IsNullOrWhiteSpace([string]$row.message)) {
            Add-ValidationError "${filePath}: message is empty."
        }
        if ([string]::IsNullOrWhiteSpace([string]$row.correlation_id)) {
            Add-ValidationError "${filePath}: correlation_id is empty."
        }

        $timestamp = Parse-AuditTimestamp -Value ([string]$row.timestamp)
        if ($timestamp -eq [datetime]::MinValue) {
            Add-ValidationError "${filePath}: Invalid timestamp '$($row.timestamp)'."
        }

        $sequenceNo = 0L
        if (-not [long]::TryParse([string]$row.sequence_no, [ref]$sequenceNo)) {
            Add-ValidationError "${filePath}: Invalid sequence_no '$($row.sequence_no)'."
        } elseif ($previousSeq -ne [long]::MinValue -and $sequenceNo -le $previousSeq) {
            Add-ValidationError "${filePath}: sequence_no must be strictly increasing. Saw $sequenceNo after $previousSeq."
        } else {
            $previousSeq = $sequenceNo
        }

        $chartId = 0L
        if (-not [long]::TryParse([string]$row.chart_id, [ref]$chartId)) {
            Add-ValidationError "${filePath}: Invalid chart_id '$($row.chart_id)'."
        }

        $brokerError = 0
        if (-not [int]::TryParse([string]$row.broker_error, [ref]$brokerError)) {
            Add-ValidationError "${filePath}: Invalid broker_error '$($row.broker_error)'."
        }

        if ($AllowedStages -notcontains [string]$row.stage) {
            Add-ValidationError "${filePath}: Invalid stage '$($row.stage)'."
        }
        if ($AllowedResultCodes -notcontains [string]$row.result_code) {
            Add-ValidationError "${filePath}: Invalid result_code '$($row.result_code)'."
        }
        if ($AllowedSeverities -notcontains [string]$row.severity) {
            Add-ValidationError "${filePath}: Invalid severity '$($row.severity)'."
        }
    }

    $groups = @{}
    foreach ($row in $rows) {
        $correlationId = [string]$row.correlation_id
        if (-not $groups.ContainsKey($correlationId)) {
            $groups[$correlationId] = New-Object 'System.Collections.Generic.List[object]'
        }
        $groups[$correlationId].Add($row)
    }

    $totalCorrelations += $groups.Keys.Count
    $fileDangerousConfirmedChains = 0

    foreach ($correlationId in ($groups.Keys | Sort-Object)) {
        $groupRows = @($groups[$correlationId] | Sort-Object { [long]$_.sequence_no })
        $actionIds = @($groupRows | ForEach-Object { [string]$_.action_id } | Select-Object -Unique)
        if ($actionIds.Count -ne 1) {
            Add-ValidationError "$filePath [$correlationId]: Multiple action_id values found."
            continue
        }

        $scopeTags = @($groupRows | ForEach-Object { [string]$_.scope_tag } | Select-Object -Unique)
        if ($scopeTags.Count -ne 1) {
            Add-ValidationError "$filePath [$correlationId]: Multiple scope_tag values found."
        }

        $actionId = $actionIds[0]
        $isDangerous = ($DangerousActionIds -contains $actionId)

        $intentRows = Get-GroupStageRows -Rows $groupRows -Stage "Intent"
        $confirmedRows = Get-GroupStageRows -Rows $groupRows -Stage "Confirmed"
        $expiredRows = Get-GroupStageRows -Rows $groupRows -Stage "Expired"
        $outcomeRows = Get-GroupStageRows -Rows $groupRows -Stage "Outcome"

        if ($intentRows.Count -gt 1) {
            Add-ValidationError "$filePath [$correlationId]: Multiple Intent rows."
        }
        if ($confirmedRows.Count -gt 1) {
            Add-ValidationError "$filePath [$correlationId]: Multiple Confirmed rows."
        }
        if ($expiredRows.Count -gt 1) {
            Add-ValidationError "$filePath [$correlationId]: Multiple Expired rows."
        }
        if ($outcomeRows.Count -gt 1) {
            Add-ValidationError "$filePath [$correlationId]: Multiple Outcome rows."
        }

        if ($isDangerous) {
            if ($intentRows.Count -eq 1) {
                $intentSeq = [long]$intentRows[0].sequence_no
                if ($confirmedRows.Count -eq 1) {
                    if ($expiredRows.Count -gt 0) {
                        Add-ValidationError "$filePath [$correlationId]: Confirmed dangerous action cannot also expire."
                    }
                    if ($outcomeRows.Count -ne 1) {
                        Add-ValidationError "$filePath [$correlationId]: Confirmed dangerous action requires exactly one Outcome row."
                    } else {
                        $confirmedSeq = [long]$confirmedRows[0].sequence_no
                        $outcomeSeq = [long]$outcomeRows[0].sequence_no
                        if ($confirmedSeq -le $intentSeq) {
                            Add-ValidationError "$filePath [$correlationId]: Confirmed row must follow Intent."
                        }
                        if ($outcomeSeq -le $confirmedSeq) {
                            Add-ValidationError "$filePath [$correlationId]: Outcome row must follow Confirmed."
                        }
                        $fileDangerousConfirmedChains++
                    }
                } elseif ($expiredRows.Count -eq 1) {
                    if ($outcomeRows.Count -gt 0) {
                        Add-ValidationError "$filePath [$correlationId]: Expired dangerous action cannot also emit an Outcome row."
                    }
                    $expiredSeq = [long]$expiredRows[0].sequence_no
                    if ($expiredSeq -le $intentSeq) {
                        Add-ValidationError "$filePath [$correlationId]: Expired row must follow Intent."
                    }
                } else {
                    Add-ValidationError "$filePath [$correlationId]: Dangerous Intent must resolve via Confirmed+Outcome or Expired."
                }
            } else {
                if ($confirmedRows.Count -gt 0 -or $expiredRows.Count -gt 0) {
                    Add-ValidationError "$filePath [$correlationId]: Dangerous action confirmation stages require a prior Intent row."
                }
                if ($outcomeRows.Count -ne 1) {
                    Add-ValidationError "$filePath [$correlationId]: Dangerous guard/cooldown action must emit exactly one Outcome row."
                } elseif ($ImmediateDangerousResultCodes -notcontains [string]$outcomeRows[0].result_code) {
                    Add-ValidationError "$filePath [$correlationId]: Dangerous outcome without Intent must be BlockedByGuard or CooldownActive."
                }
            }
        } else {
            if ($intentRows.Count -ne 1) {
                Add-ValidationError "$filePath [$correlationId]: Immediate action requires exactly one Intent row."
            }
            if ($confirmedRows.Count -gt 0 -or $expiredRows.Count -gt 0) {
                Add-ValidationError "$filePath [$correlationId]: Immediate action cannot emit Confirmed/Expired rows."
            }
            if ($outcomeRows.Count -ne 1) {
                Add-ValidationError "$filePath [$correlationId]: Immediate action requires exactly one Outcome row."
            }
            if ($intentRows.Count -eq 1 -and $outcomeRows.Count -eq 1) {
                $intentSeq = [long]$intentRows[0].sequence_no
                $outcomeSeq = [long]$outcomeRows[0].sequence_no
                if ($outcomeSeq -le $intentSeq) {
                    Add-ValidationError "$filePath [$correlationId]: Outcome row must follow Intent."
                }
            }
        }
    }

    $dangerousConfirmedChains += $fileDangerousConfirmedChains
    $fileErrorCount = $errors.Count - $errorsBefore
    $fileSummaries.Add([pscustomobject]@{
            File                    = $filePath
            Rows                    = $rows.Count
            Correlations            = $groups.Keys.Count
            DangerousConfirmedChain = $fileDangerousConfirmedChains
            Errors                  = $fileErrorCount
            Status                  = if ($fileErrorCount -eq 0) { "PASS" } else { "FAIL" }
        }) | Out-Null
}

if ($RequireDangerousChainEvidence -and $dangerousConfirmedChains -eq 0) {
    Add-ValidationError "No dangerous confirmed chains found. Evidence is required by policy."
}

$overallPass = ($errors.Count -eq 0)

$markdown = @()
$markdown += "# UI Audit Validation"
$markdown += ""
$markdown += "- Audit root: $AuditRoot"
$markdown += "- Min last-write filter: $($MinLastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
$markdown += "- Files evaluated: $($targetFiles.Count)"
$markdown += "- Rows evaluated: $totalRows"
$markdown += "- Correlations evaluated: $totalCorrelations"
$markdown += "- Dangerous confirmed chains: $dangerousConfirmedChains"
$markdown += "- Overall: $(To-Status $overallPass)"
$markdown += ""
$markdown += "## File Summary"
$markdown += ""
$markdown += "| File | Rows | Correlations | DangerousConfirmedChains | Errors | Status |"
$markdown += "|---|---:|---:|---:|---:|---|"
foreach ($summary in ($fileSummaries | Sort-Object File)) {
    $markdown += "| $($summary.File) | $($summary.Rows) | $($summary.Correlations) | $($summary.DangerousConfirmedChain) | $($summary.Errors) | $($summary.Status) |"
}

if ($errors.Count -gt 0) {
    $markdown += ""
    $markdown += "## Validation Errors"
    foreach ($entry in $errors) {
        $markdown += "- $entry"
    }
}

$parent = Split-Path -Path $OutputMarkdown -Parent
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
Set-Content -LiteralPath $OutputMarkdown -Value ($markdown -join "`n") -Encoding UTF8

$markdown | ForEach-Object { Write-Output $_ }

if (-not $overallPass) {
    exit 1
}
