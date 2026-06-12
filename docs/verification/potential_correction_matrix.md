# PotentialCorrection Matrix Verification (Kernel)

Date: 2026-02-27

## 1) Goal
Verify `PotentialCorrection` kernel behavior across the full input-variable surface using deterministic, repeatable matrix runs.  
This is a kernel-level gate; chart visualization review remains a separate targeted UI check.

## 2) Harness
Script:
- `Scripts/MOHY/PotentialCorrectionMatrixVerifier.mq5`

Outputs (under `MQL5/Files`):
- `MOHY/verification/potential_correction/<run_id>__matrix.csv`
- `MOHY/verification/potential_correction/<run_id>__assertions.csv` (full non-append runs)

The matrix CSV contains per-case deterministic fingerprints:
- `selection_count`
- `selection_hash`
- `full_hash`

The assertions CSV records invariant checks:
- `ENABLE_OFF_EMPTY`
- `INVALID_FIB_RANGE_EMPTY`
- `SELECTION_COUNT_STABLE_WHEN_ENABLED_VALID_FIB`
- `FACT_INVARIANTS`
- `MIN_OPPOSITE_ICI_MONOTONIC_CONFIRMED`
- `MIN_FIB_CLOSE_STRICTER_THAN_TOUCH`
- `MAX_FIB_CLOSE_LOOSER_THAN_TOUCH`
- `SUPERSEDE_DIRECTION_ANY_SUPERSET`
- `SUPERSEDE_SCOPE_FORMING_AND_CONFIRMED_SUPERSET`

Assertion helper for chunked/appended runs:
- `tools/verification/assert_potential_correction_matrix.ps1`

## 3) Matrix Domain
Profile `Lite`:
- compact subset for fast smoke verification.

Profile `Full`:
- `enable`: `{true,false}`
- `min_opposite_ici_count`: `{0,1,2,3}`
- `min_fib_level`: `{0.382,0.5,0.618}`
- `min_fib_trigger_mode`: `{Touch,CloseBeyond}`
- `max_fib_level`: `{0.618,0.786,0.886,1.0}`
- `max_fib_trigger_mode`: `{Touch,CloseBeyond}`
- `extreme_touch_epsilon_points`: `{0.0,0.1,1.0}`
- `extreme_touch_min_count`: `{1,2}`
- `supersede_direction_mode`: `{Any,OppositeOnly}`
- `supersede_scope`: `{FormingOnly,FormingAndConfirmed}`

Expected full-case count: `9216` (unless capped by `VerificationMaxCases`).
This includes invalid min/max fib range combinations to verify guard behavior.

## 4) Run Procedure
1. Compile visualizer gate (required for all changes):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/run_build_gate.ps1
```

2. Compile matrix harness:
```powershell
& 'C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe' `
  /compile:"<MQL5_ROOT>\Scripts\MOHY\PotentialCorrectionMatrixVerifier.mq5" `
  /include:"<MQL5_ROOT>" `
  /log:"<MQL5_ROOT>\docs\verification\potential_correction\artifacts\compile_matrix_harness.log"
```

3. Run script in terminal/tester on target symbol/time window:
- set `VerificationMatrixProfile=Full`
- set `VerificationSourceTimeframe` equal to `VerificationLTF`
- set valid `VerificationHTF/VerificationLTF` pair (`H1/M15`, `H2/M30`, `H4/H1`, `D1/H4`)
- provisional publication lock policy is always-on in kernel runtime; keep `VerificationIncludeProvisionalLatest=true` for metadata parity.
- optional performance controls:
  - `VerificationComputeFullHash=false` to reduce runtime/memory pressure
  - `VerificationCaseStartIndex` and `VerificationCaseCount` to run a chunk
  - `VerificationAppendDetailsCsv=true` to append chunk rows into one matrix CSV by `run_id`
  - `VerificationSkipAssertions=true` for chunked runs

4. Chunked run pattern (recommended when full single run is unstable):
```text
Run A chunks:
- run_id=PC_EURUSD_RUN_A, start=0,    count=1000, append=true, skipAssertions=true
- run_id=PC_EURUSD_RUN_A, start=1000, count=1000, append=true, skipAssertions=true
- ...
- run_id=PC_EURUSD_RUN_A, start=6000, count=0,    append=true, skipAssertions=true

Run B chunks:
- same pattern with run_id=PC_EURUSD_RUN_B
```

5. Build assertions CSV from merged/appended matrix CSV (chunk mode):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/assert_potential_correction_matrix.ps1 `
  -MatrixCsv "<path-to-__matrix.csv>" `
  -OutputAssertionsCsv "docs/verification/potential_correction/artifacts/<run_id>__assertions.csv"
```

6. Summarize one run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/summarize_potential_correction_matrix.ps1 `
  -MatrixCsv "<path-to-__matrix.csv>" `
  -AssertionsCsv "<path-to-__assertions.csv>" `
  -OutputMarkdown "docs/verification/potential_correction/artifacts/matrix_summary.md"
```

## 5) Determinism Replay
Run the same config/data window at least twice, then compare:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verification/compare_potential_correction_matrix.ps1 `
  -MatrixCsvFiles "<run1_matrix.csv>","<run2_matrix.csv>" `
  -OutputMarkdown "docs/verification/potential_correction/artifacts/matrix_compare.md" `
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
