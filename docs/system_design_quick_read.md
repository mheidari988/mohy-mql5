# MOHY System Design Quick Read (MT5)

Date: 2026-03-24

Purpose: fast map of active runtime modules.

## Active Documentation Contract
- Strategy behavior: `docs/strategy.md`.
- Layer ownership and runtime wiring: `docs/architecture.md`.
- Lean roadmap and verification selector: `docs/development_operating_model.md`.
- Read only the relevant section for the touched surface; do not treat historical phase ledgers as active workflow.

## Active Stack
1. Domain Contracts + Shared Config
- `Include/MOHY/Domain/Enums.mqh`
- `Include/MOHY/Domain/Config.mqh`
- `Include/MOHY/Domain/Contracts.mqh`
- `Include/MOHY/Domain/StateIds.mqh`

2. Core Price-Action Kernel
- `Include/MOHY/Core/PriceActionKernel.mqh`
- `Include/MOHY/Core/Domain/PriceActionEnums.mqh`
- `Include/MOHY/Core/Domain/PriceActionContracts.mqh`
- `Include/MOHY/Core/Domain/SnapshotSelectors.mqh`
- `Include/MOHY/Core/Builders/ElementBuilder.mqh`
- `Include/MOHY/Core/Builders/LegBuilder.mqh`
- `Include/MOHY/Core/Builders/Swing3Builder.mqh`
- `Include/MOHY/Core/Builders/PotentialImpulseBuilder.mqh`
- `Include/MOHY/Core/Builders/PotentialCorrectionBuilder.mqh`
- `Include/MOHY/Core/Builders/PotentialContinuationBuilder.mqh`
- `Include/MOHY/Core/Builders/TradeSetupPlanner.mqh`
- `Include/MOHY/Core/Builders/TradeSetupPlanBuilder.mqh`
- `Include/MOHY/Core/Builders/HistoricalTradeSetupBuilder.mqh`
- `Include/MOHY/Core/Classifiers/Swing3PatternClassifier.mqh`
- `Include/MOHY/Core/Compat/TerminalSeries.mqh`
- Kernel also publishes deterministic correction recency/active ranking, kernel-owned correction/continuation/setup selection facts, continuation confirmation signals from confirmed-correction windows with configurable trigger confirmation mode (`ConfirmedPOnly` or `POrPStar`), and correction timeline/anchor projections for all consumers.
- Next kernel publication stage after continuation is `TradeSetupPlan`, which owns executable entry/stop/target planning under risk/execution rules rather than treating continuation broken levels as final entries.
- Kernel now also publishes `HistoricalTradeSetup` facts for deterministic chart-history replay of setup outcomes (`Missed`, `Entered`, `TargetHit`, `StopHit`, `Open`) without pushing replay logic into consumers.
- Kernel execution-facing facts also publish stable runtime lineage identifiers so runtime and visualization can join the same impulse/setup lifecycle without duplicating identity formulas.
- Snapshot lineage/index selection is centralized in `SnapshotSelectors` under core domain so EA/runtime and visualizer consume identical selector behavior.
- Kernel snapshot publication is runtime-locked to include provisional latest facts; compatibility flags must not downgrade snapshots to confirmed-only mode.

3. Read-only Visualization Host
- `Indicators/MOHY_Visualizer.mq5`
- Maps MT5 `input` values into shared `StrategyConfig/DetectionConfig`.
- Builds tick snapshots from kernel and renders only published facts.
- Does not rebuild correction/continuation/setup outcome selection from candles; only applies chart/view projection to kernel facts.

4. Phase-five Runtime + Execution Hosts
- `Include/MOHY/Runtime/*`
- `Experts/MOHY_DebugEA.mq5`
- `Experts/MOHY_TradeEA.mq5`
- Runtime layer owns stable `impulse_id` / `setup_key` generation, consumed-impulse persistence, waiting-state persistence/recovery, pending-order orchestration, open-position rebinding, persisted break-even and post-BE management context, operator-action confirmation/cooldown, UI audit trail persistence, terminal alerts, panel actions, engine-event logging, and authoritative lifecycle publication through `lifecycle_state.csv` plus append-only `lifecycle_events.csv`.
- Runtime role modes are explicit: `GlobalLive`, `ShadowDebug`, `ReadOnly`; only `GlobalLive` has execution authority.
- Both execution hosts build execution-timeframe snapshots only, require `publishes_execution_stage_facts=true`, and consume selected `TradeSetupPlan` facts only.
- `MOHY_DebugEA` defaults to `ShadowDebug` for parity/debug inspection.
- In phase `P2`, `MOHY_TradeEA` defaults to `ShadowDebug` and runs timer-driven scanning (`OnTimer`) independent of chart tick cadence over a configurable scanner universe: `MarketWatchAll` (default) or `ChartSymbolOnly` (chart symbol only).
- In phase `P3`, `MOHY_TradeEA` classifies every scanned symbol into exactly one primary bucket: `ConfirmedPotentialImpulse`, `ConfirmedImpulseAndConfirmedCorrection`, `ConfirmedSetupWaitingEntry`, `EligibleNow`, `EnteredOpenRunning`, `BlockedByRiskOrExposure`, or `RejectedOrInvalidated`.
- In phase `P4`, `MOHY_TradeEA` adds deterministic candidate ranking over opportunity buckets with fixed tie-break order and top-rank diagnostics in scanner summaries.
- In phase `P5`, `MOHY_TradeEA` applies a deterministic portfolio allocator over ranked actionable candidates using `PortfolioMaxActiveTrades` + `MaxConcurrentRiskPercent` (exposure-base percent), and publishes explicit allocator accept/block diagnostics.
- In phase `P6`, enabling `EnableLiveExecutionOwnership=true` with `RuntimeRoleMode=GlobalLive` (scanner+allocator required) dispatches ranked + allocator-accepted actionable symbols through per-symbol `GlobalLive` runtime cycles, and forces the chart-attached runtime to `ReadOnly` to prevent dual ownership.
- Phase `P6` scanner summaries add execution diagnostics (`exec=[Att/Ok/Fail]` and first-error line when present).
- In phase `P7`, `MOHY_TradeEA` publishes artifact-bus JSON files for live inspectability under `MQL5/Files/MOHY/runtime/portfolio/<scope_tag>/`: per-symbol `live_snapshot_<symbol>.json` and aggregate `portfolio_state.json` with schema/version metadata and scanner/allocator/execution state, including scanner-universe mode metadata.
- In phase `P8`, `MOHY_TradeEA` renders a single-window global control panel that shows scanner/bucket summaries, allocator/execution counters, top-ranked symbol rows, dangerous-action confirmation/cooldown state, and last global action result.
- In phase `P8`, enabling the global panel on `MOHY_TradeEA` disables/clears the legacy runtime panel on that chart so there is one authoritative control surface.
- In phase `P8`, global panel actions are portfolio-broadcast (`Pause`, `Resume`, `Cancel Waiting`, `Close Trades`, `Emergency Flatten`) via per-symbol runtime dispatch, with dangerous-action stage/confirm flow and UI-audit logging.
- In phase `P8`, global panel actions emit centralized portfolio-scope UI audit rows while suppressing per-symbol alert/audit fan-out during dispatch.
- Phase-five runtime still excludes external notification channels beyond terminal alerts and any UI-driven strategy-rule mutation.

5. Verification Automation (Determinism)
- `Scripts/MOHY/KernelSnapshotDeterminismVerifier.mq5`
- `Scripts/MOHY/PotentialImpulseMatrixVerifier.mq5`
- `Scripts/MOHY/PotentialCorrectionMatrixVerifier.mq5`
- `tools/verification/run_determinism_bundle.ps1` for one-command compile/syntax checks and latest assertions summary across all three determinism verifiers.

## Excluded from Active Runtime
- `Experts/MOHY_EA.mq4`
- `Indicators/MOHY_PivotsLegs.mq4`
- `Indicators/MOHY_HtfImpulseQualified.mq4`
- `helper-tools/ConfigStudio/*`
- `helper-tools/ToolLauncher/*`

## Companion Diagram
- `docs/system_design_quick_read.drawio`

Historical verification evidence remains under `docs/verification/`; completed phase-ledger Markdown is not part of the active workflow.
