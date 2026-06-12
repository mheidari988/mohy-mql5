# PotentialImpulse Matrix Verification (Kernel)

Date: 2026-02-27

## 1) Goal
Verify `PotentialImpulse` kernel behavior across the full input-variable surface using deterministic, repeatable matrix runs.  
This is a kernel-level gate; chart visualization review remains a separate targeted UI check.

## 2) Harness
Script:
- `Scripts/MOHY/PotentialImpulseMatrixVerifier.mq5`

Outputs (under `MQL5/Files`):
- `MOHY/verification/potential_impulse/<run_id>__matrix.csv`
- `MOHY/verification/potential_impulse/<run_id>__assertions.csv`

The matrix CSV contains per-case deterministic fingerprints:
- `selection_count`
- `selection_hash`
- `full_hash`

The assertions CSV records invariant checks:
- `ENABLE_OFF_EMPTY`
- `SWING_GATE_MONOTONIC`
- `LEG_GATE_MONOTONIC_WHEN_REQUIRED`
- `DIRECTIONAL_PARAMS_IGNORED_WHEN_DIRECTIONAL_DISABLED`
- `MIN_LEG_IGNORED_WHEN_LEG_BREAKOUT_DISABLED`
- `DIAGNOSTICS_PRESENT_FOR_SELECTIONS`

## 3) Matrix Domain
Profile `Lite`:
- compact subset for fast smoke verification.

Profile `Full`:
- `enable`: `{true,false}`
- `min_swing_breakout_closes`: `{0,1,2}`
- `require_leg_breakout`: `{true,false}`
- `min_leg_breakout_closes`: `{1,2}`
- `require_directional_candles`: `{true,false}`
- `validate_endpoint_candles`: `{false,true}`
- `allow_opposite_begin_candles`: `{0,1}`
- `allow_opposite_end_candles`: `{0,1}`
- `max_opposite_middle_candles`: `{0,1}`
- `allow_any_opposite_before_leg_breakout`: `{false,true}`
- `doji_epsilon_points`: `{1e-10,0.1,1.0}`

Expected full-case count: `4608` (unless capped by `VerificationMaxCases`).

## 4) Run Procedure
1. Compile visualizer gate (required for all changes):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/run_build_gate.ps1
```

2. Compile matrix harness:
```powershell
& 'C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe' `
  /compile:"<MQL5_ROOT>\Scripts\MOHY\PotentialImpulseMatrixVerifier.mq5" `
  /include:"<MQL5_ROOT>" `
  /log:"<MQL5_ROOT>\docs\verification\potential_impulse\artifacts\compile_matrix_harness.log"
```

3. Run script in terminal/tester on target symbol/time window:
- set `VerificationMatrixProfile=Full`
- set `VerificationSourceTimeframe` and valid `VerificationHTF/VerificationLTF` pair
- provisional publication lock policy is always-on in kernel runtime; keep `VerificationIncludeProvisionalLatest=true` for metadata parity.

4. Summarize one run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/summarize_potential_impulse_matrix.ps1 `
  -MatrixCsv "<path-to-__matrix.csv>" `
  -AssertionsCsv "<path-to-__assertions.csv>" `
  -OutputMarkdown "docs/verification/potential_impulse/artifacts/matrix_summary.md"
```

## 5) Determinism Replay
Run the same config/data window at least twice, then compare:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/compare_potential_impulse_matrix.ps1 `
  -MatrixCsvFiles "<run1_matrix.csv>","<run2_matrix.csv>" `
  -OutputMarkdown "docs/verification/potential_impulse/artifacts/matrix_compare.md" `
  -CompareFullHash
```

Expected result:
- same case count,
- same case configs,
- same `selection_count` + `selection_hash` (and `full_hash` when enabled).

## 6) Acceptance Gate
- Build gate: PASS.
- Matrix assertions: all PASS.
- Determinism compare: PASS.
- Then perform targeted manual visual checks for render/tooltip correctness in `MOHY_Visualizer`.

## 7) Bundle Gate (Optional, Recommended)
After generating matrix/assertion files, run the one-command bundle gate:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/run_determinism_bundle.ps1 -RequireAssertions
```

This confirms compile/syntax + latest assertions status across:
- `KernelSnapshotDeterminismVerifier`
- `PotentialImpulseMatrixVerifier`
- `PotentialCorrectionMatrixVerifier`
