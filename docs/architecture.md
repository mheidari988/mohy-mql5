# MOHY Architecture (MT5)

Date: 2026-03-24

## 1) Active Runtime Scope
The active MT5 runtime scope is intentionally narrow:
- Core price-action kernel: `Include/MOHY/Core/*`
- Core domain contracts/config enums: `Include/MOHY/Domain/*`
- Shared EA/runtime orchestration support: `Include/MOHY/Runtime/*`
- Read-only visual consumer: `Indicators/MOHY_Visualizer.mq5`
- Debug/shadow execution consumer: `Experts/MOHY_DebugEA.mq5`
- Portfolio execution consumer: `Experts/MOHY_TradeEA.mq5`

Excluded from this MT5 migration:
- `Experts/MOHY_EA.mq4`
- `Indicators/MOHY_PivotsLegs.mq4`
- `Indicators/MOHY_HtfImpulseQualified.mq4`
- `helper-tools/ConfigStudio/*`
- `helper-tools/ToolLauncher/*`

## 2) Active Source Contract
Normative precedence:
1. `docs/strategy.md` for trading behavior.
2. `docs/architecture.md` for module ownership, runtime wiring, and layering.
3. `docs/ui-spec.md` only for visualizer and panel/control-plane behavior.

Operational companions:
- `docs/development_operating_model.md`: lean workflow, roadmap, and verification selector.
- `docs/backtesting.md`: detailed verification command catalog.
- `docs/config_profiles.md`: config registry workflow.
- `docs/playground.md`: visual artifact workflow.

Default reading policy:
- Start from code and `AGENTS.md`.
- Use `rg` to open only the relevant doc section.
- Do not update companion docs unless the public contract they own changed.

## 3) Module Boundaries
- `Include/MOHY/Domain/*`: timeframe rules, strategy config data structures, enum contracts.
- `Include/MOHY/Core/Domain/*`: kernel-facing fact contracts (`PriceActionContracts`, `PriceActionEnums`) and shared snapshot selectors (`SnapshotSelectors`) consumed by builders, runtime, and renderer.
- `Include/MOHY/Core/*`: deterministic detection builders (`Element`, `Leg`, `Swing3`, `PotentialImpulse`, `PotentialCorrection`, `PotentialContinuation`, `TradeSetupPlan`, historical setup replay) and kernel orchestration, including correction recency/active ranking, continuation/setup selection publication, correction timeline/segment projections, continuation confirmation publication from confirmed-correction windows with configurable trigger confirmation mode (`ConfirmedPOnly` or `POrPStar`), active risk-aware `TradeSetupPlan` publication after continuation confirmation, signal-time setup lineage freezing for historical replay, stable runtime identity publication on execution-facing facts, and explicit correction anchor families (`reference` decision anchors vs `visual` projection anchors).
- `Include/MOHY/Core/Compat/TerminalSeries.mqh`: MT5 compatibility wrappers for timeframe-typed terminal series APIs.
- `Include/MOHY/Runtime/*`: phase-five execution/runtime helpers for stable setup/impulse identity construction, runtime persistence, waiting-state recovery, pending-order orchestration, open-position rebinding, break-even plus post-BE management state recovery, operator-action confirmation/cooldown, UI audit trail persistence, terminal alerts, panel rendering, engine-event logging, and authoritative lifecycle-state publication (`lifecycle_state.csv` + `lifecycle_events.csv`) keyed by stable runtime lineage IDs.
- `Indicators/MOHY_Visualizer.mq5`: read-only render host; maps indicator inputs into shared config structs, consumes only kernel-published facts plus read-only runtime lifecycle artifacts, uses shared core selectors for lineage/focus joins, and performs chart/view projection only.
- `Experts/MOHY_DebugEA.mq5`: debug/shadow execution host; maps EA inputs into shared config structs, uses shared runtime engine role modes (`GlobalLive`, `ShadowDebug`, `ReadOnly`), and defaults to non-authoritative debug mode for parity inspection.
- `Experts/MOHY_TradeEA.mq5`: portfolio host advanced through phases `P2/P8`; runs timer-driven (`OnTimer`) scan cycles over a configurable scanner universe (`MarketWatchAll` default, optional `ChartSymbolOnly`) with shared kernel snapshots on the configured execution timeframe pair, publishes one deterministic primary bucket per scanned symbol (`ConfirmedPotentialImpulse`, `ConfirmedImpulseAndConfirmedCorrection`, `ConfirmedSetupWaitingEntry`, `EligibleNow`, `EnteredOpenRunning`, `BlockedByRiskOrExposure`, `RejectedOrInvalidated`), applies deterministic candidate ranking with fixed tie-break order, runs portfolio allocator guards (active-trade cap + concurrent-risk cap) with deterministic accept/block reasons, dispatches live execution through per-symbol `GlobalLive` runtime cycles for allocator-accepted actionable candidates, publishes artifact-bus JSON snapshots (`live_snapshot_<symbol>.json`, `portfolio_state.json`) for screenshot-free inspection, and renders a TradeEA-global control panel that supports portfolio-wide operator actions (`Pause`, `Resume`, `Cancel Waiting`, `Close Trades`, `Emergency Flatten`) with dangerous-action confirmation/cooldown and UI audit emission.
- `playground/*`: read-only collaboration/debug visualization tooling over exported artifacts; not part of MT5 runtime orchestration.

Rendering has no trade authority.
Detection/publication remains separate from chart-object rendering.

## 4) Runtime Data Flow
1. `MOHY_Visualizer` resolves configured HTF/LTF pair.
2. `MOHY_Visualizer` resolves one authoritative chart-anchored lookback window from `LookbackBars` and maps that time window into each source timeframe before requesting kernel snapshots.
3. Snapshot publishes confirmed + provisional objects together with pair metadata (`ContextTimeframe`, `ExecutionTimeframe`) and stage-availability flags so consumers know whether execution-stage artifacts are authoritative for that snapshot source timeframe. Execution-stage facts (`PotentialCorrection`, `PotentialContinuationSignal`, `TradeSetupPlan`, `HistoricalTradeSetup`) are authoritative only on execution-timeframe snapshots; continuation facts remain structural confirmation artifacts and expose only confirmation/broken-level anchors, not executable entry anchors.
4. Execution consumers and execution-facing visual consumers must consume kernel-published `TradeSetupPlan` facts for executable entry/stop/target planning and kernel-published `HistoricalTradeSetup` facts for past setup replay instead of deriving those values from raw candles or continuation broken levels directly.
5. Stable runtime lineage identifiers (`runtime_impulse_id`, `runtime_setup_key`) are published on execution-facing kernel facts so the EA/runtime and visual consumers can join to the same lifecycle without consumer-specific identity formulas.
6. Visualizer renders labels/lines/ribbon/impulse/correction/continuation/setup-history overlays from snapshot only, using kernel-provided facts for chart geometry and without recomputing correction/continuation/setup outcome semantics from raw candles; continuation overlay is optional debug, while `TradeSetupPlan` plus `HistoricalTradeSetup` are the primary execution-facing visualizations.
7. In `CurrentPotentialOnly`, the visualizer now acts as lifecycle-focus mode: it resolves the runtime scope from symbol + configured pair + `RuntimeMagicNumber`, reads `lifecycle_state.csv` read-only when available, joins by kernel-published `runtime_setup_key` / `runtime_impulse_id`, and clamps every overlay to the same lifecycle `[start,end]` window.
8. When no matching runtime lifecycle record is available, the visualizer falls back deterministically to kernel lineage (`PotentialImpulse`, `PotentialCorrection`, `PotentialContinuationSignal`, `TradeSetupPlan`, `HistoricalTradeSetup`) rather than reconstructing state from candles.
9. Consumer-side history scope is controlled only by the shared `LookbackBars` window plus the visualizer history mode (`CurrentPotentialOnly` vs `LookbackHistory`); per-overlay legacy history caps are not authoritative.
10. `MOHY_DebugEA`/`MOHY_TradeEA` hosts currently build execution-timeframe snapshots only, require `publishes_execution_stage_facts=true`, and consume only kernel-selected `TradeSetupPlan` facts.
11. In phase `P2`, `MOHY_TradeEA` runs a timer-driven scanner independent of chart tick cadence (`OnTimer` + per-symbol kernel `BuildRecent`) over a configurable scan universe: `MarketWatchAll` (default, `SymbolsTotal(true)` / `SymbolName`) or `ChartSymbolOnly` (chart `Symbol()` only).
12. In phase `P3`, `MOHY_TradeEA` classifies each scanned symbol into exactly one primary opportunity bucket using kernel-published facts and setup-plan metadata (`plan_state`, `reject_reason`, `exposure_pass`) without consumer candle reselection.
13. In phase `P4`, `MOHY_TradeEA` computes deterministic ranking for opportunity buckets with explicit score fields and fixed tie-break key order (`bucket_priority desc`, `ranking_score desc`, `selection_rank asc`, `setup_time desc`, `symbol asc`) and emits top-rank diagnostics in scanner logs.
14. In phase `P5`, `MOHY_TradeEA` applies deterministic portfolio allocator rules over ranked actionable candidates (`EligibleNow` / `ConfirmedSetupWaitingEntry`) using `PortfolioMaxActiveTrades`, `MaxConcurrentRiskPercent`, and exposure-base percent calculations; blocked candidates are re-bucketed to `BlockedByRiskOrExposure` with explicit allocator reason codes.
15. `MOHY_TradeEA` scanner defaults to shadow-only behavior and places no live orders unless live ownership is explicitly enabled.
16. In phase `P6`, enabling `EnableLiveExecutionOwnership=true` with `RuntimeRoleMode=GlobalLive`, scanner enabled, and allocator enabled dispatches ranked + allocator-accepted actionable symbols into per-symbol `GlobalLive` runtime cycles; scanner logs publish execution diagnostics (`exec=[Att/Ok/Fail]` plus first-error details).
17. In phase `P6` live-ownership mode, the chart-attached runtime instance is forced to `ReadOnly` so only per-symbol dispatched runtime instances own live execution and management.
18. Phase-five runtime publishes authoritative lifecycle artifacts keyed by stable `runtime_setup_key`: `lifecycle_state.csv` as the latest per-setup state table and `lifecycle_events.csv` as the append-only transition history that preserves real managed-exit timing after active runtime state is cleared.
19. Shared phase-five runtime (`Include/MOHY/Runtime/*`) owns:
   - waiting-entry tracking keyed by stable `setup_key`
   - waiting-state persistence/recovery on restart
   - broker pending-order placement, modify/cancel/replace, and fill reconciliation for `RealPendingOrder`
   - per-impulse duplicate blocking keyed by stable `impulse_id`
   - open-position rebinding on restart/reattach
   - break-even arming/activation with:
     - virtual risk-free exit for `VirtualTrigger`
     - broker `SL` move/retry/fallback handling for `RealPendingOrder`
   - post-BE start-mode activation (`Immediate`, `AfterBreakEven`, `AtRMultiple`)
   - trailing / partial / hybrid management routing, including runner behavior
   - break-even and post-BE management-state persistence/recovery on restart
   - panel state plus `Pause` / `Resume`, `Cancel Waiting`, `Close Strategy Trades`, and `Emergency Flatten`
   - dangerous-action confirmation/cooldown state
   - UI action audit trail with pre/post state hashes and result codes
   - terminal alert emission for key runtime events and failures
   - structured engine-event logging
   - lifecycle snapshot publication for waiting/open/resolved states and actual resolved-exit timestamps
20. Shared phase-five runtime explicitly does not own:
   - external notification channels beyond terminal alerts
   - any strategy-state mutation sourced from UI interactions
21. In phase `P7`, `MOHY_TradeEA` writes file-based inspectability artifacts under `MQL5/Files/MOHY/runtime/portfolio/<scope_tag>/`: per-symbol `live_snapshot_<symbol>.json` plus aggregate `portfolio_state.json`, both including `schema_version`, `run_id`, `config_hash`, timeframe context, rank/allocator/execution diagnostics, and freshness timestamps.
22. In phase `P8`, `MOHY_TradeEA` adds an EA-level global control panel (single chart window) that visualizes scanner buckets, ranking rows, allocator/execution counters, pending dangerous-action confirmation state, and last action result.
23. In phase `P8`, when the global panel is enabled in `MOHY_TradeEA`, the legacy per-chart runtime panel is disabled/cleared to avoid dual-panel ambiguity on the same chart.
24. In phase `P8`, global panel actions are broadcast to scanned symbols through per-symbol runtime instances; dangerous actions are staged/confirmed with cooldown guards, and every action path emits UI-audit rows with correlation/pre-hash/post-hash/result semantics.
25. In phase `P8`, portfolio-global UI audit rows are emitted under the portfolio runtime scope, and per-symbol dispatch used by global panel actions suppresses terminal-alert/file-audit fan-out to avoid duplicate noise.

Provisional publication policy:
- Runtime kernel publication is locked to include provisional latest facts.
- Consumer-level compatibility flags must not disable provisional publication in kernel snapshots.

## 5) Determinism Contract
- Same symbol history + same inputs must produce the same kernel snapshot stream.
- Confirmation state must remain explicit on published facts.
- Consumer apps (`Indicator`, future `EA`) must share kernel-published correction selection/timeline facts, continuation confirmation facts, and setup-plan facts; no duplicated candle-level correction reconstruction or risk-aware entry recomputation from raw candles is allowed.
- Consumer selection/index resolution must use shared core snapshot selectors; consumer-specific fallback ranking logic is not allowed.
- Consumers must rely on kernel-published snapshot metadata for stage availability instead of inferring hidden timeframe rules from array emptiness or consumer-specific conventions.
- No hidden UI/manual state is allowed to mutate detection semantics.

## 6) Build Contract
Primary build gate target:
- `Indicators/MOHY_Visualizer.mq5`
- `Experts/MOHY_DebugEA.mq5`
- `Experts/MOHY_TradeEA.mq5`

Gate tooling:
- `tools/verification/run_build_gate.ps1`
- `tools/verification/validate_build_gate.ps1`

## 7) Auxiliary Tooling (Non-Runtime)
- TradingView parity/inspection scripts live under `tools/tradingview/*`.
- Current utility: `tools/tradingview/MOHY_Kernel_PeakValley_PV_Only.pine`.
- These scripts are visualization helpers only; they do not participate in MT5 runtime orchestration and do not override kernel strategy behavior.
- Persistent visual collaboration workspace lives under `playground/*` and follows `docs/playground.md`.

