# PotentialCorrection Matrix Summary

- Run ID: PC_EURUSD_RUN_B
- Symbol: EURUSD
- Source TF: M15
- HTF/LTF: H1/M15
- Matrix rows: 6912
- Selection count total: 272448
- Selection count min/max/avg: 0 / 86 / 39.4167
- State totals (Confirmed / Forming / Invalidated): 0 / 0 / 272448
- Invalidation totals (MaxFib / DoubleExtreme / Supersede): 77544 / 43008 / 151896
- Assertions: 9 PASS, 0 FAIL
- Overall: PASS

## Assertions

| Rule | Pass | Violations | Sample |
|---|---|---:|---|
| ENABLE_OFF_EMPTY | PASS | 0 |  |
| INVALID_FIB_RANGE_EMPTY | PASS | 0 |  |
| SELECTION_COUNT_STABLE_WHEN_ENABLED_VALID_FIB | PASS | 0 |  |
| FACT_INVARIANTS | PASS | 0 |  |
| MIN_OPPOSITE_ICI_MONOTONIC_CONFIRMED | PASS | 0 |  |
| MIN_FIB_CLOSE_STRICTER_THAN_TOUCH | PASS | 0 |  |
| MAX_FIB_CLOSE_LOOSER_THAN_TOUCH | PASS | 0 |  |
| SUPERSEDE_DIRECTION_ANY_SUPERSET | PASS | 0 |  |
| SUPERSEDE_SCOPE_FORMING_AND_CONFIRMED_SUPERSET | PASS | 0 |  |
