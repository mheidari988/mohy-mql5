# MOHY Backtesting and Verification (MT5)

Date: 2026-03-17

## 1) Scope
Current verification scope is indicator/kernel integrity for:
- `Indicators/MOHY_Visualizer.mq5`
- `Include/MOHY/Core/*`
- `Include/MOHY/Runtime/*`
- `Experts/MOHY_DebugEA.mq5`
- `Experts/MOHY_TradeEA.mq5`

## 2) Build Gate (Required)
Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/run_build_gate.ps1
```

Default MT5 compiler path used by the script:
- `C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe`

Validation output:
- `docs/verification/mt5_migration/artifacts/build_gate_validation.md`

## 3) Manual Visual Checks (Targeted)
On a chart with `MOHY_Visualizer` attached:
1. Confirm HTF/LTF pair validation accepts only `H1/M15`, `H2/M30`, `H4/H1`, `D1/H4`, and rejects any non-listed pair.
2. Confirm both confirmed and provisional states are visible in labels/tooltips/status.
3. Confirm potential-correction defaults:
   - all overlays share the same chart-anchored `LookbackBars` window,
   - switching between `CurrentPotentialOnly` and `LookbackHistory` changes scope consistently across peak/valley, ribbon, impulse, correction, continuation, and setup overlays,
   - in `CurrentPotentialOnly`, lifecycle focus starts from linked impulse begin rather than correction begin,
   - when matching runtime lifecycle state exists, `CurrentPotentialOnly` ends on actual runtime resolution time and may render the one matched historical setup outcome,
   - when runtime lifecycle state is missing, `CurrentPotentialOnly` falls back deterministically to kernel lineage with stable start/end behavior,
   - no overlay persists materially older history than the others for the same `LookbackBars` setting.
4. Confirm object redraw stays deterministic after chart timeframe changes.
5. Confirm no trade/order operations are performed by the indicator.

## 4) Reproducibility
For identical symbol/time window/input set:
- compile/syntax logs should stay green,
- visual state transitions should be consistent across reruns.

## 5) PotentialImpulse Matrix Verification (Kernel)
Use the matrix harness to validate `PotentialImpulse` behavior across input-variable combinations:
- Script: `Scripts/MOHY/PotentialImpulseMatrixVerifier.mq5`
- Playbook: `docs/verification/potential_impulse_matrix.md`

Automation helpers:
- `tools/verification/summarize_potential_impulse_matrix.ps1`
- `tools/verification/compare_potential_impulse_matrix.ps1`

## 6) PotentialCorrection Matrix Verification (Kernel)
Use the matrix harness to validate `PotentialCorrection` behavior across correction-parameter combinations:
- Script: `Scripts/MOHY/PotentialCorrectionMatrixVerifier.mq5`
- Playbook: `docs/verification/potential_correction_matrix.md`

Automation helpers:
- `tools/verification/summarize_potential_correction_matrix.ps1`
- `tools/verification/compare_potential_correction_matrix.ps1`
- `tools/verification/assert_potential_correction_matrix.ps1` (build assertions for chunked/appended matrix runs)

## 7) Core Snapshot Determinism Verification (Kernel)
Use the replay harness to validate deterministic fingerprints for:
- `elements`
- `legs`
- `swings3`
- `potential_impulses`
- `potential_corrections`
- `potential_continuation_signals`
- `trade_setup_plans`
- `historical_trade_setups`

Script:
- `Scripts/MOHY/KernelSnapshotDeterminismVerifier.mq5`

Playbook:
- `docs/verification/kernel_snapshot_determinism.md`

## 8) Determinism Bundle Runner
Use one command to compile/syntax-check the three determinism verifiers and summarize latest assertion CSVs:
- `tools/verification/run_determinism_bundle.ps1`

Example:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/run_determinism_bundle.ps1 -RequireAssertions
```

## 9) EA Phase-five Strategy Tester Checks
Targeted EA verification scope:
- for `MOHY_TradeEA` single-pair Strategy Tester runs, set `ScanUniverseMode=ChartSymbolOnly` to constrain scanner evaluation to the chart/tester symbol (`MarketWatchAll` remains the default portfolio mode)
- immediate `EligibleNow` execution enters once with static broker `SL/TP`
- `WaitingForPullback` execution enters only after a closed-candle virtual cross
- `RealPendingOrder` places the correct broker pending order type for waiting-entry plans
- pending auto-modify updates price/SL/TP in place when lots are unchanged and cancel-replaces when normalized lots move by at least one lot step
- spread/risk/exposure rejection prevents entry and emits deterministic reason evidence
- pre-entry invalidation clears waiting state and blocks re-entry for the same impulse
- the same impulse cannot be entered twice after entry or after pre-entry invalidation
- a later new impulse can still produce a new entry
- break-even arms on `HTF` impulse-extreme touch for an open `VirtualTrigger` trade
- break-even virtual risk-free exit closes the trade when price returns to the persisted net-zero break-even level
- break-even for `RealPendingOrder` moves broker `SL` to net-zero BE and falls back deterministically if the broker move remains blocked
- restart/reattach recovers one open MOHY position and its persisted break-even context
- restart/reattach restores waiting-entry state and pending-order linkage when a waiting setup is still authoritative
- `PostBEStartMode = Immediate` starts management without waiting for BE
- `PostBEStartMode = AfterBreakEven` starts management only after BE activation
- `PostBEStartMode = AtRMultiple` starts management only after the configured realized-R threshold is reached
- `TrailOnly` updates stops according to the selected trail model/cadence without loosening risk protection
- `PartialOnly` executes one to three partial legs deterministically and updates remaining management state
- `Hybrid` combines partial execution and trailing on the remaining runner deterministically
- `RunnerTargetMode = TrailOnlyRunner` removes runner TP after the first successful partial and leaves the remainder stop-driven
- restart/reattach recovers persisted post-BE management state, including started/not-started status, partial progress, and trailing context
- management actions respect the `ApplyExecFiltersToManagement` setting when enabled
- paused EA suppresses new entries while leaving the open trade untouched
- pause/resume suspends and restores pending waiting-entry ownership deterministically
- dangerous actions require confirmation/cooldown routing before execution
- panel actions cancel waiting, close strategy trade, and emergency flatten route correctly and persist deterministic runtime evidence
- UI audit evidence records intent, confirmation/expiry, outcome, pre-state hash, post-state hash, and broker error/result code when enabled
- terminal alerts emit once per relevant runtime transition and remain suppressible by config
- multiple matching MOHY positions force a blocked/manual-cleanup state

## 10) Runtime Lifecycle Parity Verification
Use the runtime-artifact verifier to validate one runtime scope after EA/tester runs that generated fresh lifecycle evidence:
- Script: `Scripts/MOHY/RuntimeLifecycleParityVerifier.mq5`
- Playbook: `docs/verification/runtime_lifecycle_parity.md`

Targeted parity checks:
- `lifecycle_state.csv` latest rows remain structurally valid for waiting/open/resolved branches
- `lifecycle_events.csv` stays append-only with increasing sequence numbers
- latest lifecycle event per `setup_key` matches the corresponding `lifecycle_state.csv` row
- `waiting_state.csv` matches the active `WAITING` lifecycle row when present
- `tracked_position.csv` matches the active `OPEN` lifecycle row when present
- runtime evidence remains aligned across restart recovery, pending replacement, BE, trailing, partials, hybrid, and manual/runtime resolution branches

## 11) TradeEA Artifact Bus Verification
Use the artifact-bus validator after TradeEA JSON writer/schema changes, or after a fresh TradeEA run when live inspectability needs checking:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/validate_tradeea_artifact_bus.ps1
```

After generating fresh artifacts from the current TradeEA build, require the enriched selected-plan fields:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/validate_tradeea_artifact_bus.ps1 -RequireEnrichedFields
```
