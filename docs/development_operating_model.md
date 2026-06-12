# MOHY Lean Development Operating Model (MT5)

Date: 2026-06-04

Purpose: keep MOHY from drifting without spending every session rewriting Markdown.

## 1) Active Reference Set
- `AGENTS.md`: session routing, scope, and documentation budget.
- `docs/strategy.md`: only trading-behavior authority. Read the relevant section, not the whole file, unless the change is broad.
- `docs/architecture.md`: module ownership, runtime wiring, and layering.
- `docs/ui-spec.md`: only when changing visualizer or panel/control-plane behavior.
- `docs/backtesting.md`: command catalog for verification.
- `docs/config_profiles.md` and `docs/playground.md`: only when working on those surfaces.

Completed phase ledgers and status matrices are not active planning tools. Do not recreate or update them unless explicitly requested.

## 2) Coding-First Roadmap
Current baseline: the MT5 kernel, visualizer, DebugEA, TradeEA, runtime artifact bus, and global panel are delivered. Future work should default to code and verification.

Priority order:
1. Fix compile, runtime, and tester defects in active MT5 files.
2. Implement user-requested strategy, risk, runtime, or visualization changes in the shared owner module first.
3. Tighten runtime/visualizer parity using lifecycle artifacts and targeted verifiers.
4. Add or improve verification only for the module being changed.
5. Keep platform research, long-form evidence bundles, and historical phase planning outside normal coding sessions unless requested.

## 3) Change Workflow
1. Inspect code first with `rg`/targeted file reads.
2. If strategy behavior changes, patch the exact `docs/strategy.md` section before code.
3. If module ownership, runtime wiring, UI behavior, public config, or verification commands change, patch the relevant doc once, scoped to that contract.
4. For routine bug fixes, refactors, compile fixes, and internal implementation details, skip doc edits unless a public contract changed.
5. Implement the smallest safe code change in the owning layer.
6. Run the narrowest verification gate that proves the changed surface.
7. End with the short `docs/session_handoff.md` summary.

Do not spend a session updating multiple docs just to repeat the same decision. Link to the authority or name the affected section instead.

## 4) Verification Selector
- Any MQL code change: run `tools/verification/run_build_gate.ps1`.
- Kernel object graph or snapshot publication changes: run the build gate, then the kernel snapshot determinism verifier when behavior changed.
- `PotentialImpulse` logic changes: run its matrix verifier/summarizer only for logic or gate changes.
- `PotentialCorrection` logic changes: run its matrix verifier/summarizer only for correction lifecycle, fib, supersede, or anchor changes.
- Runtime/EA changes: compile the affected EA and run targeted Strategy Tester/manual checks for the touched branch.
- Lifecycle artifact changes: run `Scripts/MOHY/RuntimeLifecycleParityVerifier.mq5` against the affected runtime scope when fresh artifacts exist.
- Visualizer rendering changes: build gate plus one targeted chart check for the touched overlay/mode.
- Docs-only changes: no MT5 compile required; verify references with `rg`.

Full determinism bundles and broad tester matrices are milestone/release gates or explicit user requests, not the default for every task.

## 5) Debug and Playground Shortcuts
- `debug` means inspect `MQL5/Files/MOHY/debug_window/last_run_pointer.csv`, then open the referenced CSV. Field details live in `docs/verification/window_debug_export.md`.
- Use `playground/` for visual artifact review. Generated run artifacts stay under `playground/artifacts/runs/`.
- Playground tooling remains read-only with respect to strategy logic.
