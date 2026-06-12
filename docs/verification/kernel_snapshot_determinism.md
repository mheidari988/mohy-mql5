# Kernel Snapshot Determinism Verification (Kernel Snapshot + Setup Pipeline)

Date: 2026-02-27

## 1) Goal
Verify deterministic, repeatable kernel fingerprints for the core snapshot pipeline:
- `elements`
- `legs`
- `swings3`
- `potential_impulses`
- `potential_corrections`
- `potential_continuation_signals`
- `trade_setup_plans`
- `historical_trade_setups`

This harness covers the active kernel ladder from foundational structure through setup publication/history replay.

## 2) Harness
Script:
- `Scripts/MOHY/KernelSnapshotDeterminismVerifier.mq5`

Outputs (under `MQL5/Files`):
- `MOHY/verification/kernel_snapshot/<run_id>__matrix.csv`
- `MOHY/verification/kernel_snapshot/<run_id>__assertions.csv`

`matrix.csv` includes per-pass fingerprints:
- counts per published layer
- `elements_hash`, `legs_hash`, `swings3_hash`
- `potential_impulses_hash`, `potential_corrections_hash`
- `potential_continuation_signals_hash`, `trade_setup_plans_hash`, `historical_trade_setups_hash`
- `combined_hash`

`assertions.csv` includes replay stability checks:
- `ELEMENT_HASH_STABLE`
- `LEG_HASH_STABLE`
- `SWING3_HASH_STABLE`
- `POTENTIAL_IMPULSE_HASH_STABLE`
- `POTENTIAL_CORRECTION_HASH_STABLE`
- `CONTINUATION_HASH_STABLE`
- `TRADE_SETUP_PLAN_HASH_STABLE`
- `HISTORICAL_SETUP_HASH_STABLE`
- `COMBINED_HASH_STABLE`

## 3) Run Procedure
1. Build gate first:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/run_build_gate.ps1
```

2. Compile harness:
```powershell
& 'C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe' `
  /compile:"<MQL5_ROOT>\Scripts\MOHY\KernelSnapshotDeterminismVerifier.mq5" `
  /include:"<MQL5_ROOT>" `
  /log:"<MQL5_ROOT>\docs\verification\kernel_snapshot\artifacts\compile_kernel_snapshot_harness.log"
```

3. Run script in terminal/tester:
- choose target `symbol`, `source timeframe`, and valid `HTF/LTF` pair
- set `VerificationReplayPasses >= 2`
- keep same chart/history state during the run

## 4) Acceptance Gate
- Build gate: PASS.
- Harness assertions: all PASS.
- Replay fingerprints stable across passes.

## 5) Notes
- Provisional publication policy is locked ON in kernel runtime.
- The harness always fingerprints snapshots with provisional publication enabled.

## 6) One-Command Bundle (All Determinism Verifiers)
Use:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/run_determinism_bundle.ps1 -RequireAssertions
```

This wrapper:
- compiles/syntax-checks:
  - `KernelSnapshotDeterminismVerifier`
  - `PotentialImpulseMatrixVerifier`
  - `PotentialCorrectionMatrixVerifier`
- discovers the latest `__assertions.csv` under:
  - `Files/MOHY/verification/kernel_snapshot`
  - `Files/MOHY/verification/potential_impulse`
  - `Files/MOHY/verification/potential_correction`
- emits consolidated markdown summary:
  - `docs/verification/determinism/artifacts/determinism_bundle_summary.md`
