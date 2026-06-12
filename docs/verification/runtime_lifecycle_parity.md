# Runtime Lifecycle Parity Verification

Date: 2026-03-18

## Goal
Validate Phase 4 runtime parity for one runtime scope using the EA-authored runtime artifacts, without re-deriving execution state from candles.

This verifier is for read-only checks over:
- `lifecycle_state.csv`
- `lifecycle_events.csv`
- `waiting_state.csv`
- `tracked_position.csv`

## Script
- `Scripts/MOHY/RuntimeLifecycleParityVerifier.mq5`

## Scope Resolution
Use one of:
1. explicit `VerificationScopeTag`
2. `VerificationSymbol` + `VerificationHTF` + `VerificationLTF` + `RuntimeMagicNumber`

Default pair validation still follows MOHY rules:
- `H1/M15`
- `H2/M30`
- `H4/H1`
- `D1/H4`

## What The Verifier Checks
- lifecycle snapshot and lifecycle event files exist and are readable
- `lifecycle_state.csv` setup keys are unique and scoped correctly
- lifecycle rows have valid waiting/open/resolved shape and time ordering
- `lifecycle_events.csv` sequence numbers are strictly increasing
- latest append-only lifecycle event for each `setup_key` matches the current lifecycle snapshot row
- `waiting_state.csv` matches the active `WAITING` lifecycle row when present
- `tracked_position.csv` matches the active `OPEN` lifecycle row when present
- active unresolved lifecycle rows stay limited to one runtime-owned setup at a time

## Output
Default output directory:
- `MQL5/Files/MOHY/verification/runtime_lifecycle`

Files written per run:
- `*__details.csv`
- `*__assertions.csv`

The verifier still writes assertions when evidence is missing so Phase 4 gaps show up as explicit failures instead of a silent no-op.

## Recommended Manual Flow
1. Run `Experts/MOHY_DebugEA.mq5` or `Experts/MOHY_TradeEA.mq5` in the target scenario until the runtime folder contains fresh lifecycle artifacts.
2. Run `RuntimeLifecycleParityVerifier` against the same scope.
3. Review `*__assertions.csv` first.
4. If an assertion fails, inspect `*__details.csv` and the runtime folder files for that scope.
5. Cross-check the same setup on `Indicators/MOHY_Visualizer.mq5` in `CurrentPotentialOnly`.

## Recommended Scenario Coverage
Run the verifier after EA/tester samples for:
- waiting virtual-trigger flow
- waiting pending-order placement/update/replacement
- open trade with break-even activation
- trailing-only post-BE management
- partial-only post-BE management
- hybrid post-BE management
- restart recovery for waiting and open trade
- manual close / emergency flatten / broker-resolved exit branches

## Notes
- This verifier is artifact-parity only. It does not replace Strategy Tester checks.
- Normative runtime behavior remains in `docs/strategy.md`, `docs/architecture.md`, and `docs/backtesting.md`.
