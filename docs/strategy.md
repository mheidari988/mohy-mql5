# MOHY Strategy Specification

## 1) Objective
Define a deterministic, backtestable multi-timeframe continuation strategy that trades in the direction of a strong higher-timeframe impulse after a weaker lower-timeframe retracement and lower-timeframe structural continuation under a configurable confirmation mode.

### 1.1 Runtime Direction (2026-02-25)
- Active implementation scope is now:
  - core price-action engine (`Include/MOHY/Core/*`)
  - shared EA runtime support (`Include/MOHY/Runtime/*`)
  - `Experts/MOHY_DebugEA.mq5`
  - `Experts/MOHY_TradeEA.mq5`
  - `Indicators/MOHY_Visualizer.mq5`
  - fresh strategy/architecture documentation
- Excluded from MT5 migration:
  - `Experts/MOHY_EA.mq4`
  - `Indicators/MOHY_PivotsLegs.mq4`
  - `Indicators/MOHY_HtfImpulseQualified.mq4`
  - `helper-tools/ConfigStudio/*`
  - `helper-tools/ToolLauncher/*`

Companion documents, used only when the touched surface requires them:
- `docs/architecture.md` for module/layer boundaries and runtime state contracts.
- `docs/ui-spec.md` for UI control-plane behavior and audit contracts.
- `docs/backtesting.md` for verification command details.
- `docs/development_operating_model.md` for the lean coding workflow and active roadmap.

These companion docs do not add strategy rules. Trading behavior remains in this file.

### 1.2 EA Phase 5 Active Runtime Scope (2026-03-17)
`Experts/MOHY_TradeEA.mq5` is the active live execution orchestrator around the shared kernel.
`Experts/MOHY_DebugEA.mq5` remains the shadow/debug execution host.

Phase-five live execution scope is:
- supported entry modes:
  - `VirtualTrigger`
  - `RealPendingOrder`
- supported post-entry behavior:
  - static broker `SL/TP`
  - mode-specific break-even management on `HTF` impulse-extreme touch:
    - `VirtualTrigger`: virtual/internal risk-free exit when price returns to the computed net-zero break-even level
    - `RealPendingOrder`: broker `SL` move to the computed net-zero break-even level with retry/fallback handling
  - configurable post-BE management modules:
    - `TrailOnly`
    - `PartialOnly`
    - `Hybrid`
  - supported post-BE start modes:
    - `Immediate`
    - `AfterBreakEven`
    - `AtRMultiple`
  - mode-coupled management ownership:
    - `VirtualTrigger`: internal trailing, partials, runner state, and virtual stop routing
    - `RealPendingOrder`: broker `SL/TP` updates and broker partial-close routing
- supported UI/control plane:
  - status panel with execution-mode visibility
  - `Pause` / `Resume` as immediate actions
  - `Cancel Waiting`
  - `Close Strategy Trades`
  - `Emergency Flatten`
  - dangerous-action confirmation/cooldown routing for:
    - `Cancel Waiting`
    - `Close Strategy Trades`
    - `Emergency Flatten`
  - structured UI audit trail with:
    - action intent
    - confirmation
    - outcome
    - pre-state hash
    - post-state hash
    - result code / broker error evidence
  - terminal alerting for key runtime events and failures behind config
  - panel visibility for confirmation/cooldown state and last management action result
- supported restart behavior:
  - recover one open MOHY trade on reattach/restart
  - recover persisted break-even and post-BE management context for that trade
  - restore waiting-entry state, including pending-order linkage when applicable
- supported concurrency guard: one entry per impulse structure

Phase-five live runtime explicitly excludes:
- strategy-rule mutation from UI or alerts
- external notification channels beyond terminal alerts / panel visibility
- any re-derivation of candle/structure logic outside kernel contracts

## 2) Timeframes and Decision Cadence
- Timeframe pair is configurable by `TimeframePair` with allowed values:
  - `H1/M15` (default)
  - `H2/M30`
  - `H4/H1`
  - `D1/H4`
- The listed pairs are authoritative:
  - intraday pairs use a strict 4:1 `HTF:LTF` duration ratio
  - `D1/H4` is the explicit daily-context pair and must not be replaced with an undocumented `H6` pair
- `HTF` must be strictly higher than `LTF`.
- Higher timeframe (context): selected `HTF`
- Lower timeframe (confirmation and execution): selected `LTF`
- Kernel recomputation loop: every market tick.
- Kernel publication model:
  - `Confirmed` facts: satisfy full close-based confirmation rules.
  - `Provisional` facts: latest evolving states that can include open candle (`shift=0`) and right-side-incomplete pivots.
- Provisional publication lock policy:
  - kernel snapshot publication is locked to include provisional stream (`include_provisional_latest=true` effective behavior).
  - compatibility flags may still exist in callers, but they must not disable provisional publication.
- No intra-candle promotion of provisional facts into confirmed facts.
- Entry triggering in `VirtualTrigger` mode is evaluated on closed `LTF` candles only.
- `RealPendingOrder` fills remain broker-driven intrabar events.
- Chart timeframe is non-authoritative; all strategy reads must use configured `HTF/LTF` explicitly.

Notation normalization:
- In formulas and behavioral rules below, references to `H1` and `M15` represent the selected `HTF` and `LTF` pair semantics.
- Default timeframe pair remains `H1/M15`.

## 3) Core Definitions and Metrics
Calculations are split into two deterministic channels:
- Confirmed channel: closed candles only.
- Provisional channel: recomputed on every tick and allowed to include open-candle/right-side-incomplete states.

### 3.1 Canonical Price-Action Kernel Objects (Mandatory)
- The engine must build one deterministic object graph per symbol/timeframe:
  - `Candle -> PivotPoint -> Element -> Leg -> Swing3 -> PatternSemantic`
- Object definitions:
  - `PivotPoint`: swing high/low candidate derived from configured pivot rules with explicit `Confirmed|Provisional` state.
  - `Element`: pivot-bound candle semantic point with deterministic ordering, source references, and explicit `Confirmed|Provisional` state.
  - `Leg`: directional segment connecting two alternating `Element` endpoints and carrying explicit `Confirmed|Provisional` state.
  - `Swing3`: exactly three consecutive `Leg` objects (`leg1`, `leg2`, `leg3`) with mapped structure endpoints (`LL/HL/LH/HH`) and explicit `Confirmed|Provisional` state.
  - `PatternSemantic`: runtime semantic labels computed from `Swing3` (`ICI/CIC/ICC/CII`, breakout state, breakout certainty, correction state, breakout close count).
- All higher-level decisions (`Impulse`, `Retracement`, `Continuation`, `SetupPlan`) must consume only these derived objects.
- No detector is allowed to bypass kernel objects and recompute ad-hoc swings from raw candles.
- Every derived object must keep parent references (bar shift/time and parent object indices) for deterministic traceability.
- Every derived object consumed by visualization must expose whether it is confirmed or provisional.

### 3.2 Structure Terms
- Swings can exist in two states:
  - `Confirmed` swings from closed-candle-confirmed pivots.
  - `Provisional` swings from latest evolving pivots during open/right-incomplete windows.
- Any rule that requires a finalized structural decision must use confirmed swings.
- Structure labels are assigned only from confirmed swings:
  - `HH`: confirmed swing high greater than the previous confirmed swing high.
  - `LH`: confirmed swing high less than or equal to the previous confirmed swing high.
  - `HL`: confirmed swing low greater than the previous confirmed swing low.
  - `LL`: confirmed swing low less than or equal to the previous confirmed swing low.
- Canonical structure grammar is strict 4-leg chaining over alternating confirmed pivots:
  - Each structure has 4 consecutive legs and 5 pivot endpoints.
  - The next structure reuses the prior structure's leg-4 as its leg-1, then adds 3 new legs.
  - Bullish completion is a break leg close above prior structure `LH` reference.
  - Bearish completion is a break leg close below prior structure `HL` reference.
- `ABCD` notation is equivalent shorthand for the same swing sequence:
  - `A/B/C` are confirmed swing points.
  - `D` is the break leg that closes beyond the structure level derived from `C`.
- Bullish impulse break: `HTF` close above the latest confirmed previous `LH`.
- Bearish impulse break: `HTF` close below the latest confirmed previous `HL`.
- HTF impulse-eligible structural break must be semantically backed by `Swing3` pattern with terminal impulse leg:
  - bullish: `BullishICI` or `BullishCII` with `BreakState=Breakout`
  - bearish: `BearishICI` or `BearishCII` with `BreakState=Breakout`
- The governing `Swing3` for a structure break is the deterministic `Swing3` whose `leg3` end aligns to the structure break shift.
- `BrokenStructuresCount` = number of confirmed `HTF` structure levels broken by the impulse move.

### 3.3 Swing3 Semantic Taxonomy (Mandatory)
- Every `Swing3` must produce a deterministic pattern label:
  - `BullishICI`, `BullishCIC`, `BullishICC`, `BullishCII`
  - `BearishICI`, `BearishCIC`, `BearishICC`, `BearishCII`
- Pattern classification is comparison-driven using `leg1` and `leg3` endpoints and must be deterministic.
- Every `Swing3` must also publish:
  - `BreakState = Breakout | NoCloseBreak | Unknown`
  - `BreakoutCertainty = Uncertain | Certain | Unknown`
  - `CorrectionState = Retested | NotRetested | Brokeback | Unknown`
  - `BreakoutCloseCount` (integer count of qualifying closes beyond pattern reference level)
- Deterministic breakout semantics:
  - `BreakoutCloseCount >= 1` => `BreakState = Breakout`.
  - `BreakoutCloseCount == 0` with resolved reference/window => `BreakState = NoCloseBreak`.
  - unresolved/insufficient reference context => `BreakState = Unknown`.
- Deterministic certainty semantics:
  - `BreakState != Breakout` => `BreakoutCertainty = Unknown`.
  - `BreakoutCloseCount == 1` => `BreakoutCertainty = Uncertain`.
  - `BreakoutCloseCount >= 2` => `BreakoutCertainty = Certain`.
- `BreakState`, `BreakoutCertainty`, and `CorrectionState` are first-class semantic facts, not optional diagnostics.
- Pattern semantics are mandatory kernel outputs and available to all downstream modules.

### 3.4 Strength and Efficiency Formulas
- `ImpulseStrength = ImpulseRange / ImpulseCandles`
- `RetracementStrength = RetracementRange / RetracementCandles`
- `Efficiency = Abs(NetPriceChange) / Sum(CandleRanges)`

Where:
- `NetPriceChange` is move from phase start to phase end.
- `Sum(CandleRanges)` is sum of `(High - Low)` for candles in that phase.
- `ImpulseCandles` has no fixed value and can be `1` or more contiguous candles.

### 3.5 Auxiliary Impulse Metrics
These metrics are informational in the current HTF impulse qualifier and are not impulse-gating filters:
- `SingleCandleShock = LargestImpulseCandleRange / ImpulseRange`
- `StructureDepthScore` derived from `BrokenStructuresCount` against structural references.

### 3.6 Retracement Depth Metrics
- `RetraceDepth = Abs(RetraceExtreme - ImpulseExtreme) / Abs(ImpulseOrigin - ImpulseExtreme)`
- `RetraceMinLevel` selectable from `{0.382, 0.5, 0.618}` (default `0.382`)
- `RetraceMaxLevel` default `0.786` (next standard level after `0.618`, configurable)

### 3.7 Risk Base Definitions
- `RiskBase` and `ExposureBase` are selectable from:
  - `Equity`
  - `Balance`
  - `CalculatedBalance`
- `CalculatedBalance` means account balance adjusted by open-trade worst-case stop-loss impact (remaining balance if all active stops are hit).

### 3.8 Tick Publication Contract (Active Runtime)
- Engine/kernel must recompute and publish latest snapshot on every tick.
- Snapshot must include both historical confirmed objects and latest provisional objects in one ordered stream.
- Publication lock: snapshot publication must not be downgraded to confirmed-only mode at runtime.
- Provisional object eligibility:
  - open candle (`shift=0`) is allowed.
  - bars lacking full right-side confirmation window are allowed.
- Confirmation promotion rule:
  - provisional objects become confirmed only after required close/right-window constraints are satisfied.
- Visualization must make provisional status explicit in labels/tooltips/status text.

### 3.9 PotentialImpulse Publication Contract (Kernel)
- `PotentialImpulse` is a kernel-published artifact derived from `Swing3` + selected impulse leg and is consumed by visualization.
- The selected impulse leg is deterministic by pattern:
  - `ICI/CII -> leg3`
  - `CIC -> leg2`
  - `ICC -> leg1`
- Swing close-break gate is close-count based:
  - `PotentialImpulseMinSwingBreakoutCloses = 0` disables swing close-break filtering.
  - `PotentialImpulseMinSwingBreakoutCloses >= 1` requires `Swing3.BreakState=Breakout` and `Swing3.BreakoutCloseCount >= PotentialImpulseMinSwingBreakoutCloses`.
  - default is `1` (any close-confirmed breakout). `2` maps to certain breakout under current certainty semantics.
- Leg close-break gate:
  - when `PotentialImpulseRequireLegBreakout=true`, selected impulse leg must close beyond its leg reference level at least `PotentialImpulseMinLegBreakoutCloses` times (default `1`).
- Directional candle purity gate remains configurable and deterministic:
  - `PotentialImpulseRequireDirectionalCandles`
  - `PotentialImpulseValidateEndpointCandles`
  - `PotentialImpulseAllowOppositeBeginCandles`
  - `PotentialImpulseAllowOppositeEndCandles`
  - `PotentialImpulseMaxOppositeMiddleCandles`
  - `PotentialImpulseAllowAnyOppositeBeforeLegBreakout` (default `true`)
  - `PotentialImpulseDojiEpsilonPoints`
- Published impulse facts must include a deterministic diagnostics string with reason code `Reason=PI_OK` and gate-path metadata (swing gate, leg gate, leg-context status, directional gate pass).

### 3.10 PotentialCorrection Publication Contract (Kernel)
- `PotentialCorrection` is a kernel-published retracement artifact and is linked `1:1` to a confirmed `PotentialImpulse`.
- `PotentialCorrection` lifecycle states are:
  - `Forming`
  - `Confirmed`
  - `Invalidated`
- Start condition:
  - correction tracking starts only after `PotentialImpulse.confirmed=true`.
  - correction anchor references are split and explicit:
    - decision/reference anchors (used by correction math and state transitions):
      - `ReferenceBeginShift/Time`: linked potential-impulse end extreme projected into execution timeframe coordinates using deterministic intra-window price matching against `PotentialImpulse.end_price` (fallback: directional window extreme).
      - `ReferenceBeginPrice`: linked impulse extreme (`PotentialImpulse.end_price`).
    - visual anchors (used only for chart projection):
      - `VisualBeginShift/Time/Price`: linked potential-impulse end extreme projected into execution timeframe coordinates using deterministic intra-window price matching against `PotentialImpulse.end_price` (fallback: directional window extreme).
      - if impulse-end projection is unavailable, visual anchors must deterministically fall back to reference anchors.
      - active runtime policy: visual and reference begin anchors must be identical to avoid indicator/EA drift.
  - correction detection window begins from the first execution candle strictly after the begin anchor candle.
  - correction depth and invalidation math remains anchored to linked impulse bounds (`ImpulseOrigin = PotentialImpulse.begin_price`, `ImpulseExtreme = PotentialImpulse.end_price`).
- Retracement depth metric (relative to linked impulse):
  - `RetraceDepth = Abs(RetraceExtreme - ImpulseExtreme) / Abs(ImpulseOrigin - ImpulseExtreme)`
- Confirmation requires both gates simultaneously on the same kernel publication step:
  - opposite-`ICI` gate:
    - bullish impulse correction requires cumulative confirmed bearish `ICI` count `>= PotentialCorrectionMinOppositeICICount` (default `1`)
    - bearish impulse correction requires cumulative confirmed bullish `ICI` count `>= PotentialCorrectionMinOppositeICICount` (default `1`)
    - `PotentialCorrectionMinOppositeICICount` is an integer threshold with allowed range `0..N` (`N` bounded only by integer range)
    - when `PotentialCorrectionMinOppositeICICount = 0`, opposite-`ICI` gate is treated as satisfied (no opposite-direction `ICI` required)
    - counting is cumulative within correction window (not consecutive-only)
    - only confirmed lower-timeframe swings are counted
  - minimum-fib gate:
    - `RetraceDepth >= PotentialCorrectionMinFibLevel`
    - trigger mode is configurable:
      - `PotentialCorrectionMinFibTriggerMode = Touch | CloseBeyond` (default `Touch`)
    - allowed `PotentialCorrectionMinFibLevel` enum values (fixed global set):
      - `0.382` (default)
      - `0.5`
      - `0.618`
- Invalidation gates:
  - maximum-fib breach:
    - `RetraceDepth > PotentialCorrectionMaxFibLevel`
    - trigger mode is configurable:
      - `PotentialCorrectionMaxFibTriggerMode = Touch | CloseBeyond` (default `Touch`)
    - allowed `PotentialCorrectionMaxFibLevel` enum values (fixed global set):
      - `0.618`
      - `0.786` (default)
      - `0.886`
      - `1.0`
  - impulse-extreme double-top/double-bottom breach:
    - reference level is exactly linked `PotentialImpulse.end_price`
    - default comparator is equal-or-beyond with single-touch wick sensitivity:
      - bullish impulse correction invalidates when retracement high touches/reaches/exceeds impulse extreme
      - bearish impulse correction invalidates when retracement low touches/reaches/breaks below impulse extreme
    - tolerance is configurable in points (`PotentialCorrectionExtremeTouchEpsilonPoints`, default `0`)
    - minimum touch count is configurable (`PotentialCorrectionExtremeTouchMinCount`, default `1`)
- Supersede gate (context replacement by new `HTF` swing):
  - correction can be terminated when a new confirmed `HTF Swing3` is detected.
  - direction filter is configurable:
- `PotentialCorrectionSupersedeDirectionMode = Any | OppositeOnly` (default `OppositeOnly`)
  - supersede scope is configurable:
- `PotentialCorrectionSupersedeScope = FormingOnly | FormingAndConfirmed` (default `FormingAndConfirmed`)
  - supersede terminal reason is published as `SupersededByNewHTFSwing`.
- A confirmed correction can still transition to `Invalidated` before entry if any invalidation/supersede gate fires.
- Configuration consistency rule:
  - `PotentialCorrectionMaxFibLevel` must be strictly greater than `PotentialCorrectionMinFibLevel`.
- Published correction facts must include:
  - linked `PotentialImpulse` identifiers
  - state
  - terminal reason (when non-active)
  - reference begin anchors (`ReferenceBeginShift/Time/Price`)
  - visual begin anchors (`VisualBeginShift/Time/Price`)
  - min/max fib thresholds and active trigger modes
  - opposite-`ICI` count and configured minimum
  - current retracement depth and correction extreme coordinates
  - deterministic recency metadata (`RecencyRank`, `IsActive`) for latest-correction selection
  - deterministic timeline projections for both full-history and trimmed-history views, including:
    - timeline extreme endpoint
    - forming segment endpoint
    - confirmed segment anchors (when available)
    - invalidated segment anchors (when available)
  - deterministic diagnostics string
- Consumers (`Indicators`, `EAs`, tools) must consume these published correction projections directly and must not recompute correction selection/segments from raw candles outside kernel/core modules.

### 3.11 PotentialContinuationSignal Publication Contract (Kernel)
- `PotentialContinuationSignal` is a kernel-published structural continuation-confirmation artifact linked to one published `PotentialCorrection`.
- Signal generation start gate:
  - linked correction must have reached `Confirmed` state (`ConfirmedShift >= 0`).
  - scan starts strictly after correction confirmation candle close.
- Continuation trigger confirmation mode is configurable by `ContinuationPlanningStartMode`:
  - `ConfirmedPOnly`: only confirmed `LTF Swing3` and confirmed trigger legs are eligible.
  - `POrPStar` (default): both provisional and confirmed `LTF Swing3`/trigger legs are eligible.
- Signal generation stop gate:
  - signals are produced only while linked correction remains in confirmed-state window.
  - if correction later transitions to `Invalidated`, signal scan ends strictly before invalidation candle close.
- Qualifying continuation pattern:
  - pattern must be continuation-direction `ICI` relative to linked impulse direction:
    - bullish impulse -> `BullishICI`
    - bearish impulse -> `BearishICI`
  - `BreakState` must be `Breakout` (`breakout_close_count >= 1`).
- Broken-level rule:
  - one continuation signal is emitted per qualifying `ICI` breakout.
  - signal broken level is the continuation structure level on the `C` leg that got broken by the qualifying breakout:
    - bullish continuation: `C`-leg highest level (middle-leg `leg2` begin extreme / break level)
    - bearish continuation: `C`-leg lowest level (middle-leg `leg2` begin extreme / break level)
  - broken-level anchor candle is the candle that owns that broken `C`-leg extreme.
- Execution-boundary rule:
  - `PotentialContinuationSignal` does not define executable trade entry price, stop-loss, take-profit, or position sizing.
  - The signal declares that continuation conditions are satisfied under the selected start mode and that execution planning may start from the next eligible `LTF` closed candle onward.
  - continuation facts must not publish executable-looking entry anchors such as `EntryShift/Time/Price`; consumers must anchor continuation visuals from `BrokenLeg*`, `BrokenLevel*`, and `Signal*` fields only.
- Repeated-signal rule:
  - every new qualifying continuation-direction `ICI` breakout emits another continuation signal.
  - signal emission continues until correction state leaves its confirmed window.
- Published continuation signal facts must include:
  - linked correction and linked impulse identifiers
  - linked correction recency metadata (`RecencyRank`, `IsActive`)
  - continuation direction
  - correction confirmation anchor (`ConfirmedShift/Time`)
  - qualifying `Swing3` identifiers and breakout metadata (`BreakoutCertainty`, `BreakoutCloseCount`)
  - broken-leg anchors (`BrokenLegBeginShift/Time`, `BrokenLegEndShift/Time`)
  - signal anchor (`SignalShift/Time`)
  - broken continuation level anchor (`BrokenLevelShift/Time/Price`)
  - kernel-owned continuation selection metadata (`SelectionRank`, `IsSelected`)
  - deterministic diagnostics string
- Consumers (`Indicators`, `EAs`, tools) must consume these published continuation facts directly and must not re-derive continuation windows from raw candles outside kernel/core modules.
  - continuation visualization is audit/debug-only; execution-facing consumers must treat `TradeSetupPlan` as the final actionable stage.

### 3.12 TradeSetupPlan Publication Contract (Kernel)
- `TradeSetupPlan` is a kernel-published execution-planning artifact linked to one published `PotentialContinuationSignal`.
- `TradeSetupPlan` starts only after continuation confirmation exists and represents the first risk-aware stage where executable trade parameters may be proposed.
- Planning responsibility:
  - continuation detection remains structural and strategy-semantic.
  - trade setup planning resolves executable entry, stop-loss, take-profit, reward-to-risk feasibility, and pre-entry waiting state from configurable risk/execution rules.
- Inputs consumed by setup planning must include:
  - stop placement policy
  - target placement policy
  - `MinRR` and `RRTolerance`
  - execution mode (`VirtualTrigger`, `RealPendingOrder`)
  - spread/slippage/commission assumptions used by trigger math
  - post-entry management mode (`Off`, `TrailOnly`, `PartialOnly`, `Hybrid`)
- Allowed stop candidate families must be explicit and deterministic:
  - continuation local stop (`leg2` terminal extreme)
  - previous qualifying structure extreme
  - full correction extreme
  - any additional stop mode must be documented here before implementation
- Allowed target candidate families must be explicit and deterministic:
  - fixed reward-to-risk projection
  - structure-derived target
  - HTF-context target
  - any additional target mode must be documented here before implementation
- Planning algorithm:
  1. Resolve linked continuation signal and linked correction/impulse context.
  2. Enumerate allowed stop candidates.
  3. Enumerate allowed target candidates.
  4. Evaluate immediate executable entry using side-aware executable price.
  5. If immediate execution satisfies configured RR, spread, and exposure rules, publish executable-now plan.
  6. Otherwise solve required improved entry price from chosen stop, target, and `MinRR`.
  7. If a valid improved entry exists, publish waiting-for-pullback plan with trigger price.
  8. If no valid executable or waiting plan can satisfy risk rules, publish an ineligible plan with deterministic rejection reason.
- `TradeSetupPlan` lifecycle states must be explicit:
  - `Ineligible`
  - `EligibleNow`
  - `WaitingForPullback`
  - `Invalidated`
- Pre-entry invalidation is part of setup planning itself:
  - live setup publication and historical replay must reuse the same configured invalidation threshold and mode
  - if the setup has not entered and the threshold is already breached, the published setup plan must become `Invalidated`
- Published setup plan facts must include:
  - linked continuation/correction/impulse identifiers
  - linked correction recency metadata needed for kernel-owned current setup selection
  - setup anchor (`SetupShift/Time`) used as the deterministic start of plan lineage
  - direction
  - plan state
  - proposed execution mode
  - proposed trigger/order price actually used by the selected execution mode
  - expected executable entry price after applying configured trigger-cost assumptions
  - required executable entry threshold that satisfies configured RR
  - trigger touch side (`LowCost`, `Bid`, `Ask`)
  - spread estimate, slippage estimate, commission estimate, and total entry-cost points used by trigger math
  - chosen stop price and stop-anchor type
  - chosen target price and target-anchor type
  - computed reward-to-risk ratio
  - configured minimum reward-to-risk threshold
  - risk-distance metrics required for position sizing
  - chosen post-entry management mode
  - waiting-policy metadata needed for execution ownership:
    - `RecheckMode`
    - `AdjustCadence`
    - `AdjustMinSeconds`
    - `RecheckRRAtTrigger`
    - `MinTriggerMovePoints`
    - trigger-freeze enable flag and freeze threshold
    - pending auto-modify enable flag
  - kernel-owned setup selection metadata (`SelectionRank`, `IsSelected`)
  - deterministic diagnostics string
- Consumers (`EAs`, indicators, tools) must consume these published setup plans directly and must not recompute risk-aware executable entry/stop/target from raw candles outside kernel/core modules.
- EA live-routing note:
  - `TradeSetupPlan` remains the final actionable kernel stage for execution.
  - live execution consumes both `VirtualTrigger` and `RealPendingOrder` behaviors from this contract.
  - live execution treats `EligibleNow` and `WaitingForPullback` as the only executable states.
  - waiting-entry monitoring remains in the EA/runtime layer:
    - closed-candle virtual trigger ownership for `VirtualTrigger`
    - broker pending-order placement/modify/cancel/replace/fill ownership for `RealPendingOrder`
  - after entry, the EA/runtime layer owns break-even, post-BE start-mode activation, trailing, partials, runner routing, and mode-coupled stop execution using the already selected kernel plan plus persisted setup anchors.

### 3.13 HistoricalTradeSetup Publication Contract (Kernel)
- `HistoricalTradeSetup` is a kernel-published audit/replay artifact derived from published setup-plan lineage, the same shared setup-planning model used by `TradeSetupPlan`, and deterministic execution-timeframe candle scanning.
- Purpose:
  - render full historical setup/trade lifecycle on chart when the indicator is attached to existing history
  - expose whether a published setup was entered, missed, still open, stopped, or reached target
  - keep historical replay logic inside kernel/core modules instead of inside consumers
- Historical replay must not depend on current terminal bid/ask/account state for past-candle setup existence.
- Historical replay is deterministic and candle-history based:
  - source timeframe is the configured execution timeframe
  - chart timeframe remains non-authoritative
  - same history plus same inputs must produce the same historical setup outcomes
- Historical replay must freeze setup lineage at signal-time:
  - the replayed plan must be derived from the correction/setup state that existed on the setup candle immediately after continuation confirmation
  - later correction extension, later invalidation, or later live-market costs must not rewrite the historical stop/target/trigger that existed at setup-time
- Initial lifecycle coverage in the active runtime is limited to:
  - `Waiting`
  - `Missed`
  - `Entered`
  - `TargetHit`
  - `StopHit`
  - `Open`
- Initial historical replay scope excludes full post-entry management replay:
  - break-even migration
  - trailing-stop evolution
  - partial exits
  - hybrid post-BE routing
  - those behaviors remain strategy-valid for live execution but are not yet part of the first historical audit overlay
- Entry replay semantics:
  - `VirtualTrigger` replay uses closed-candle touch/close-cross rules from Section `6.3`
  - replay starts from the first eligible closed execution candle after continuation confirmation
  - if immediate executable state exists at replay start, the setup enters on that first eligible replay candle
  - otherwise replay waits for the first qualifying trigger touch
- Pre-entry miss semantics:
  - if pre-entry invalidation fires before entry, the setup outcome is `Missed`
  - invalidation threshold uses the linked impulse extreme and configured pre-entry invalidation mode
- Post-entry outcome semantics for the initial historical overlay:
  - after entry, replay scans execution candles forward for stop/target resolution
  - `TargetHit` is published when target is reached before stop
  - `StopHit` is published when stop is reached before target
  - if both stop and target are touched within the same candle, replay uses deterministic worst-case ordering and resolves as `StopHit`
  - if neither stop nor target is resolved before snapshot end, outcome remains `Open`
- Published historical setup facts must include:
  - linked setup-plan/continuation/correction/impulse identifiers
  - setup direction
  - setup publication anchors
  - planned entry/stop/target prices
  - outcome state
  - whether entry occurred
  - entry shift/time/price when entered
  - exit shift/time/price when resolved
  - deterministic diagnostics string
- Consumers (`Indicators`, `EAs`, tools) must consume these published historical setup facts directly and must not reconstruct past setup outcomes from raw candles outside kernel/core modules.

## 4) HTF Impulse and LTF Retracement Validation (Legacy Execution Reference)

Note:
- This section remains relevant for deprecated execution modules kept for backward compatibility.
- For active implementation focus, prioritize Sections `1.1`, `2`, and `3.8` together with the core kernel contracts.

### 4.1 Structural Requirement
- A valid setup starts with a confirmed `HTF` structural break in one direction.
- Impulse detection is always structure-first (`LL/LH/HL/HH`) and never metric-first.
- In the current development phase, HTF impulse qualification runs in strict core mode and does not apply optional post-detection impulse filters.

### 4.2 Core HTF Impulse Detection Algorithm (Mandatory)
- Single required algorithm:
  1. Build confirmed `HTF` pivots using configured pivot parameters (`SwingLeftBars`, `SwingRightBars`).
  2. Normalize pivots into strict alternating `Element` stream.
  3. Build `Leg` objects from alternating `Element` endpoints.
  4. Build rolling `Swing3` objects (`leg1/leg2/leg3`) and assign mandatory semantic labels:
     - pattern taxonomy (`ICI/CIC/ICC/CII`)
     - `BreakState` (`Breakout/NoCloseBreak/Unknown`)
     - `BreakoutCertainty` (`Uncertain/Certain/Unknown`)
     - `CorrectionState` (`Retested/NotRetested/Brokeback/Unknown`)
     - `BreakoutCloseCount`
  5. Label swings using only confirmed swing highs/lows:
     - Highs are `HH` or `LH` versus the previous confirmed swing high.
     - Lows are `HL` or `LL` versus the previous confirmed swing low.
  6. Define structural break references from latest confirmed structure:
     - Bullish break reference: immediate previous confirmed `LH`.
     - Bearish break reference: immediate previous confirmed `HL`.
  7. Confirm break only by `HTF` candle close:
      - Bullish break: `Close > RefLH`
      - Bearish break: `Close < RefHL`
  9. Apply mandatory Swing3 semantic gate on the confirmed structural break:
      - Resolve governing `Swing3` whose `leg3` ends at the same break shift.
      - Bullish break is valid only if governing pattern is `BullishICI` or `BullishCII` and `BreakState=Breakout`.
      - Bearish break is valid only if governing pattern is `BearishICI` or `BearishCII` and `BreakState=Breakout`.
      - If no deterministic governing `Swing3` exists, no impulse is formed.
  10. Wick-only penetration is never a valid break.
  11. Impulse origin is the start pivot of structure leg-4 (break leg start) from canonical chain.
  12. Build impulse segment bounds:
      - Segment start = `ImpulseOriginShift` (leg-4 start pivot candle shift).
      - Segment end = structure break candle shift (`BreakCandle` fixed behavior in current qualifier).
  13. Apply mandatory candle-sequence gate on that segment:
      - Segment can be `1` or more candles.
      - Start candle can be bullish, bearish, or doji.
      - End candle can be bullish, bearish, or doji.
     - Middle candles are all candles strictly between start and end.
     - Doji middle candles (`Open == Close`) are always allowed.
     - Every non-doji middle candle must match impulse direction:
       - Bullish impulse: middle non-doji candles must be bullish.
       - Bearish impulse: middle non-doji candles must be bearish.
  14. Breakout-close can occur on the end candle or on any earlier candle inside the same impulse segment.
- Default pivot parameters are:
  - `SwingLeftBars = 1`
  - `SwingRightBars = 1`
- Dual-pivot ordering rule:
  - If the same `HTF` candle is confirmed as both swing high and swing low, keep both pivots in the alternating stream.
  - Order is determined by first occurrence on the configured lower timeframe candles inside that `HTF` candle window.
  - If both extremes first occur within the same lower timeframe candle (or lower timeframe evidence is unavailable), use deterministic fallback order:
    - bearish candle: `High` then `Low`
    - bullish/doji candle: `Low` then `High`
- Impulse purity constraint (mandatory):
  - During `HTF` impulse formation, reject candidate impulse when a full opposite-direction 4-leg structure is confirmed by close before the impulse completes.
- Deterministic handling:
  - If valid `LH/HL` break references are not available, no impulse is formed.
  - If structural break exists but governing `Swing3` is not `ICI/CII` breakout in break direction, no impulse is formed.
  - If both bullish and bearish break conditions evaluate true on the same `HTF` close, reject as ambiguous and form no impulse.
- Impulse candle count is not hard-coded; candidate impulse can be single-candle or multi-candle.
- This structure algorithm is non-negotiable and always active.

### 4.3 HTF Impulse Filter Policy (Current)
- No optional post-detection impulse filters are applied in the current HTF impulse qualifier.
- Impulse acceptance/rejection is driven only by:
  - canonical structural break + mandatory `Swing3` semantic gate (`ICI/CII` + `Breakout`),
  - strict candle-sequence validation,
  - opposite-structure purity rejection.
- Auxiliary impulse metrics (`ATR`, `Efficiency`, `RelativeVolume`, `Shock`, `StructureDepth`) are non-gating in this phase.

### 4.4 Impulse Structural Options (Configurable)
- Equal-swing classification mode:
  - `EqualSwingClassificationMode`:
    - `EqualAsWeaker` (default): equal high -> `LH`, equal low -> `LL`
    - `EqualAsStronger`: equal high -> `HH`, equal low -> `HL`
- Fixed qualifier behaviors in this phase:
  - impulse extreme uses break candle (`BreakCandle` fixed),
  - dual-direction break on same `HTF` bar is rejected as ambiguous,
  - opposite-color non-doji middle candles invalidate impulse (strict sequence).

### 4.5 Retracement Integrity
- Retracement validation is evaluated on closed `M15` candles only.
- Retracement is counter-trend relative to the impulse.
- Retracement window anchors to canonical impulse end boundary (post-break impulse extreme endpoint) and uses the same canonical kernel object graph (`Element/Leg/Swing3` + published pattern semantics).
- Retracement must not break the impulse origin (structural invalidation level).
- Retracement must remain inside the impulse range.
- Minimum retracement depth:
  - `RetraceDepth >= RetraceMinLevel`
  - `RetraceMinLevel` is selectable (`0.382`, `0.5`, `0.618`), default `0.382`
- Maximum retracement depth invalidator:
  - `RetraceDepth > RetraceMaxLevel` invalidates setup
  - default `RetraceMaxLevel = 0.786` (configurable)
  - trigger mode is configurable:
    - `RetraceInvalidationMode = Touch | CloseBeyond`
    - default `Touch` (wick touch is enough to invalidate)

### 4.6 Retracement Validation Models (Configurable)
Retracement quality is model-based and selected by input:
- `RetracementModel = StrengthEfficiencyBaseline` (default)
- Optional models for research/backtesting:
  - `CadenceSlope`
  - `VolatilityContraction`
  - `StructureStep`
  - `VolumeProfile`
  - `HybridScore`

`StrengthEfficiencyBaseline` requires both:
- `RetracementStrength < ImpulseStrength`
- `RetracementEfficiency < ImpulseEfficiency`

`CadenceSlope` requires:
- `RetracementStepRatio = RetracementStrength / ImpulseStrength`
- `RetracementStepRatio <= MaxRetracementStepRatio` (default `0.85`)

`VolatilityContraction` requires:
- `RetracementATR / ImpulseATR <= MaxRetracementATRRatio` (default `0.90`)
- ATR period is configurable:
  - `RetracementATRPeriod` (default `14`)

`StructureStep` requires all:
- `RetraceSwingCount >= MinRetraceSwingCount` (default `2`)
- `RetraceDominantCandleShare <= MaxRetraceDominantCandleShare` (default `0.60`)
- `RetraceStructureContinuityPass = true`

Definitions:
- `RetraceSwingCount` = count of confirmed retracement swings inside retracement window.
- `RetraceDominantCandleShare = LargestRetraceCandleRange / RetracementRange`.
- `RetraceStructureContinuityPass` means retracement contains at least one confirmed swing high and one confirmed swing low in the retracement window.

`VolumeProfile` requires:
- `RetraceRelativeVolume <= MaxRetraceRelativeVolume` (default `1.10`)
- `RetraceRelativeVolume = AvgRetracementVolume / AvgImpulseVolume`

`HybridScore` (retracement) uses weighted normalized components:
- Inputs:
  - `RetraceHybridWeightCadence = 0.25` (default)
  - `RetraceHybridWeightVolatility = 0.25` (default)
  - `RetraceHybridWeightStructure = 0.25` (default)
  - `RetraceHybridWeightVolume = 0.25` (default)
  - `MinRetracementScore = 0.70` (default)
- Components:
  - `CadenceScore = min(MaxRetracementStepRatio / RetracementStepRatio, 1.0)`
  - `VolatilityScore = min(MaxRetracementATRRatio / (RetracementATR / ImpulseATR), 1.0)`
  - `StructureScore = 0.5 * min(RetraceSwingCount / MinRetraceSwingCount, 1.0) + 0.5 * min(MaxRetraceDominantCandleShare / RetraceDominantCandleShare, 1.0)`
  - `VolumeScore = min(MaxRetraceRelativeVolume / RetraceRelativeVolume, 1.0)`
- Score:
  - `RetracementScore = Wcad*CadenceScore + Wvola*VolatilityScore + Wstr*StructureScore + Wvol*VolumeScore`
- Pass condition:
  - `RetracementScore >= MinRetracementScore`

All thresholds and model weights above must be input-configurable.

### 4.7 Optional Retracement Filters (Toggleable, Default Enabled)
- `EnableRetraceShockFilter = true`:
  - Reject sharp retracements using one or both:
    - `RetraceSingleCandleShock = LargestRetraceCandleRange / RetracementRange`
    - `LargestRetraceCandleRange / ATR(14)`
- `EnableRetraceSidewaysFilter = true`:
  - Reject consolidation-like pullbacks using overlap/range compression metrics.
- `EnableRetraceVolumeFilter = true`:
  - Reject retracements with abnormal counter-trend volume.
- `EnableRetraceStructureFilter = true`:
  - Require orderly counter-trend structure (progressive swings) from the canonical retracement swing stream.

All retracement filters can run as hard gates or score contributors, based on selected model.

### 4.8 Optional MA Crossover Retracement Rule
MA retracement rule is configurable and enabled by default:
- `EnableRetraceMAFilter = true`
- Inputs for each MA are configurable:
  - Period
  - Method/type (`SMA`, `EMA`, `SMMA`, `LWMA`)
  - Applied price
- Direction logic:
  - For bearish impulse setup: retracement is valid only if bullish MA crossover occurs on `M15` close.
  - For bullish impulse setup: retracement is valid only if bearish MA crossover occurs on `M15` close.
- MA crossover must happen during retracement phase and before continuation-entry confirmation.

### 4.9 Deprecated/Removed Detection Inputs
- `MinImpulseRangePoints` is removed and must not be present in active runtime config.
- `ImpulseModel` is removed and must not be present in active runtime config.
- Unknown config keys are rejected by the layered config codec.


## 5) LTF Continuation Confirmation
Continuation confirmation is valid only on `LTF` close and is published by kernel continuation facts.

- Continuation confirmation source is `PotentialContinuationSignal` (Section `3.11`).
- A continuation confirmation exists when at least one valid continuation signal is present for the active confirmed correction.
- Confirmation generation uses only:
  - confirmed correction state window,
  - continuation-direction `ICI` + `Breakout` semantics,
  - broken `C`-leg structural level anchor.
- Each new qualifying `ICI` breakout emits another continuation signal while correction remains in confirmed state.
- When correction state changes out of confirmed window, no additional continuation signals are generated for that correction.
- Continuation confirmation is an eligibility event only; it does not by itself define executable trade entry, stop-loss, or take-profit.
- Continuation confirmation may still be visualized for audit/debug, but the final user-facing execution layer is `TradeSetupPlan`.
- Risk-aware execution planning starts only after continuation confirmation and is published through `TradeSetupPlan` (Section `3.12`).

## 6) Entry Rules
Enter only when all conditions below are true:
- Valid `H1` impulse + valid retracement context exists.
- `M15` continuation confirmation exists.
- A valid `TradeSetupPlan` exists in executable state for the selected execution mode.
- Retracement depth acceptance rules are already satisfied (Section `4.5`), including configured min/max retracement levels.
- A valid `SL` and `TP` pair can be computed (Sections `7` and `8`).

Additional constraints:
- One active trade per impulse structure.
- After continuation is confirmed on candle close, execution planning is allowed from the next candle onward.
- Trade execution is allowed only when `TradeSetupPlan` resolves `EligibleNow` or a valid waiting trigger is later touched under the configured execution mode.
- No candle-count expiry is applied in this phase.
- Pre-entry invalidation after continuation is active and defined in Section `6.7`.

### 6.1 Minimum Risk-Reward Gate
- `MinRR` is input-configurable (default `2.0`).
- `RRTolerance` is input-configurable (default `0.02`).
- RR pass condition is:
  - `RR + RRTolerance >= MinRR`
- Immediate market execution is allowed only if current executable price satisfies RR pass condition.
- RR is always calculated using executable side:
  - Buy entry uses `Ask`
  - Sell entry uses `Bid`
- `PotentialContinuationSignal` never bypasses this gate; continuation confirmation only enables setup planning.
- Spread gate is configurable:
  - `EnableSpreadFilter = true`
  - `MaxSpreadPoints` input
  - If spread filter fails, execution is blocked for that check cycle.

### 6.2 Entry Execution Modes
- `EntryExecutionMode = VirtualTrigger | RealPendingOrder` (default `VirtualTrigger`).
- `TradeSetupPlan` must first attempt immediate executable entry using the current side-aware executable price.
- If immediate market entry fails RR pass condition, `TradeSetupPlan` computes improved entry trigger price and waits for touch:
  - Bearish setup: trigger is typically above current price.
  - Bullish setup: trigger is typically below current price.
- Required entry price is solved from chosen `SL`, chosen `TP`, and `MinRR`:
  - `EntryRequired = (TP + MinRR * SL) / (1 + MinRR)`
- RR basis at trigger is worst-case executable price model:
  - `RRBasisMode = WorstCaseExec` (selected default)
- Recheck mode for waiting logic is configurable:
  - `RecheckMode = WaitFixed | AdjustOnFail | AlwaysAdjust` (default `AdjustOnFail`)
- Recheck timing:
  - `WaitFixed`: trigger price is not recalculated while setup remains valid.
  - `AdjustOnFail`: recalculate trigger only after touch event fails RR/spread conditions.
  - `AlwaysAdjust`: recalculate trigger continuously on each tick.
- Recalculation cadence for adjust-capable modes:
  - `AdjustCadence = TickWithThrottle` (selected default)
  - `AdjustMinSeconds` (default `1`)
- Trigger adjustment direction is constrained to improve or preserve RR:
  - Sell trigger can stay same or move higher only.
  - Buy trigger can stay same or move lower only.
- Trigger anti-jitter threshold:
  - `MinTriggerMovePoints` (default `1`)
  - Skip trigger update if `Abs(NewTrigger - CurrentTrigger) < MinTriggerMovePoints`.
- Near-touch freeze zone:
  - `EnableTriggerFreeze = true` (selected default)
  - `FreezePoints = FreezeSpreadMultiplier * SpreadEst` (default `FreezeSpreadMultiplier = 0.5`)
  - If price distance to trigger is within freeze zone, suppress trigger chasing updates.

### 6.3 Virtual Trigger Behavior (Default)
- Virtual trigger is broker-hidden (no pending order is sent).
- Touch side is configurable:
  - `SellTriggerTouchSide = Bid | Ask | LowCost` (default `LowCost`)
  - `BuyTriggerTouchSide = Ask | Bid | LowCost` (default `LowCost`)
  - `LowCost` mapping:
    - Sell trigger uses `Bid`
    - Buy trigger uses `Ask`
- Trigger evaluation cadence:
  - Evaluate trigger touch once per newly closed `M15` candle.
  - After continuation confirmation, virtual-trigger execution is eligible from the next closed `M15` candle onward.
- Closed-candle touch semantics:
  - Use configured touch feed (`Bid`/`Ask`/`LowCost`) with unchanged `LowCost` mapping.
  - `Ask` feed on a closed candle uses deterministic spread-adjusted proxy:
    - `ObservedCloseAsk = CloseBid + SpreadEst * Point`
  - `Bid` feed on a closed candle uses:
    - `ObservedCloseBid = CloseBid`
  - Touch event is a close-cross of trigger threshold:
    - Buy setup: previous observed close `>` trigger and current observed close `<=` trigger
    - Sell setup: previous observed close `<` trigger and current observed close `>=` trigger
- On each qualifying close-cross event:
  - If RR pass condition and spread filter pass: execute immediately.
  - If RR/spread fails:
    - `WaitFixed`: keep waiting at same trigger.
    - `AdjustOnFail`: recalculate and adjust trigger, then continue waiting.
    - `AlwaysAdjust`: continue dynamic trigger updates and execute on first valid close-cross.
- Optional recheck control at touch:
  - `RecheckRRAtTrigger = true | false` (input-configurable)
  - If `false`, EA can execute on qualifying close-cross without RR re-evaluation (spread filter still applies if enabled).
- If execution attempt fails due to broker/deviation/slippage conditions:
  - `ExecutionFailMode = KeepWaitingAndRecalc` (selected default).
- Visual behavior:
  - EA draws and updates a visible virtual-entry line and state label.
  - Recommended states: `Waiting`, `RR Failed`, `Adjusted`, `Ready`.

### 6.4 Real Pending Order Behavior (Optional)
- Optional mode can place broker-visible pending orders instead of virtual triggers.
- In adjust-capable modes, pending order auto-modify is supported:
  - `EnablePendingAutoModify = true`
  - Apply same trigger recalculation rules as virtual mode.
  - On each trigger recalculation cycle, re-evaluate risk sizing and exposure using recalculated pending trigger price as effective entry.
  - If recalculated normalized lots differ from existing pending lots by at least one broker lot step, cancel existing pending order and place a replacement with updated lots/price/SL/TP.
  - If lots do not change by lot-step threshold, modify existing pending order price/SL/TP in place.
- If pending order placement/modification violates broker constraints, skip trade.

### 6.5 Deterministic Wait-vs-Adjust Algorithm
1. Resolve a `TradeSetupPlan` from continuation signal + risk/execution policy.
2. Compute planned `SL` and `TP`.
3. Check immediate executable entry RR and spread.
4. If valid, publish executable-now plan and execute market entry immediately.
5. If invalid, compute `EntryRequired`, publish waiting plan, and set trigger.
6. While setup is active:
   - `WaitFixed`: wait for touch on fixed trigger.
   - `AdjustOnFail`: wait for touch; if touch fails RR/spread, recalc and adjust trigger.
   - `AlwaysAdjust`: recalc trigger each tick using current market state.
   - In `VirtualTrigger` mode, touch checks are performed on closed `M15` candle close-cross events only.
   - For `RealPendingOrder` with `EnablePendingAutoModify = true`, each trigger adjustment cycle also re-runs lot sizing/exposure checks against recalculated pending entry.
7. On each touch event:
   - If `RecheckRRAtTrigger = true`, execute immediately on first pass of RR+spread conditions.
   - If `RecheckRRAtTrigger = false`, execute immediately on touch (subject to spread filter if enabled).
8. If execution attempt fails due to broker/deviation/slippage limits:
   - Keep waiting and recalculate trigger per selected recheck mode.
9. If pending order placement/modification (in `RealPendingOrder` mode) violates broker constraints, skip trade.
10. If pending replacement is required because normalized lots changed and cancel/replace fails, reject setup with explicit deterministic rejection reason.

### 6.6 Cost-Aware Trigger Recalculation (Live/Backtest Alignment)
This subsection defines the exact trigger computation under spread/slippage drift.

- Spread estimator (selected `2B`):
  - `SpreadEst = max(CurrentSpreadPoints, EMA(SpreadPoints, SpreadEmaPeriod))`
  - default `SpreadEmaPeriod = 20`
- Slippage estimator (selected `3B`):
  - `SlipEst = max(FixedSlippagePoints, SlippageSpreadMultiplier * SpreadEst)`
  - balanced defaults:
    - `FixedSlippagePoints = 1`
    - `SlippageSpreadMultiplier = 0.25`
- Commission estimator (selected `4B`):
  - `CommPts = FixedCommissionPoints` (input-configurable)
- Total entry cost in points:
  - `CostPts = SlipEst + CommPts`
- RR baseline entry from target and stop (selected `5A`):
  - `E_req = (TP + MinRR * SL) / (1 + MinRR)`

Trigger conversion by side and configured touch feed:
- Buy setup:
  - If touch feed is `Ask` (or `LowCost`): `TriggerAsk = E_req - CostPts`
  - If touch feed is `Bid`: `TriggerBid = E_req - CostPts - SpreadEst`
- Sell setup:
  - If touch feed is `Bid` (or `LowCost`): `TriggerBid = E_req + CostPts`
  - If touch feed is `Ask`: `TriggerAsk = E_req + CostPts + SpreadEst`

Operational notes:
- Trigger price is normalized to symbol tick size before comparison/modification.
- Backtest slippage mode is deterministic synthetic from configured inputs:
  - `BacktestSlippageMode = DeterministicSynthetic`
- Post-fill RR guard (selected `11C`):
  - `PostFillRRGuard = WarnOnly`
  - If realized RR after fill drops below threshold, log warning; do not force-close solely for this reason.

Balanced defaults profile (selected `12`):
- `SpreadEst = max(CurrentSpread, EMA20)`
- `SlipEst = max(1 point, 0.25 * SpreadEst)`
- `AdjustCadence = TickWithThrottle`, `AdjustMinSeconds = 1`
- `MinTriggerMovePoints = 1`
- `EnableTriggerFreeze = true`, `FreezeSpreadMultiplier = 0.5`

### 6.7 Pre-Entry Invalidation After Continuation
This rule applies only when continuation is confirmed and no trade has been opened yet.

- Reference invalidation level is fixed to `H1` impulse extreme:
  - Bearish setup: `H1ImpulseLow`
  - Bullish setup: `H1ImpulseHigh`
- Invalidation mode is selectable:
  - `PreEntryInvalidationMode = Touch | CloseBeyond` (default `Touch`)
- Fixed directional buffer is configurable:
  - `PreEntryInvalidationBufferPoints` (default `0`)
- Thresholds:
  - Bearish threshold: `H1ImpulseLow - PreEntryInvalidationBufferPoints`
  - Bullish threshold: `H1ImpulseHigh + PreEntryInvalidationBufferPoints`
- Trigger conditions:
  - `Touch` mode:
    - Bearish setup invalidates when market touches/prints at or below bearish threshold.
    - Bullish setup invalidates when market touches/prints at or above bullish threshold.
  - `CloseBeyond` mode:
    - Bearish setup invalidates on `M15` close at or below bearish threshold.
    - Bullish setup invalidates on `M15` close at or above bullish threshold.
- Invalidation action:
  - Cancel virtual trigger or broker pending order.
  - Mark setup invalid and block re-entry until a new valid `H1` impulse context is formed.

## 7) Stop Loss Rules
- Stop placement is model-based:
  - `SLMode = OuterCorrectionExtreme | InnerStructure | Auto` (default `OuterCorrectionExtreme`)

### 7.1 Outer Correction Extreme Stop
- Bearish setup: `SL = CorrectionHigh + OuterSLBuffer`
- Bullish setup: `SL = CorrectionLow - OuterSLBuffer`

### 7.2 Inner Structure Stop
- Uses inner retracement structure instead of full correction extreme.
- `InnerStopSwingIndex = 1` means latest inner swing against trade direction.
- Candidate order for inner swings:
  - ranked by proximity to the outer correction extreme (closest first).
- Selected inner stop also applies its own buffer:
  - `InnerSLBuffer`

### 7.3 Auto Stop Selection
- `SLMode = Auto` chooses stop candidates using this priority:
  - Try `OuterCorrectionExtreme` first.
  - If required entry/`MinRR` is not feasible, test inner candidates ranked by proximity to the outer correction stop.
  - Deterministic tie-breaker for equal proximity: lower `InnerStopSwingIndex` first.
  - Select the first candidate that can satisfy execution and `MinRR` conditions.
- No hard limit is applied to tested inner candidates while setup remains valid.

### 7.4 Stop Validation
- Trade is rejected if stop distance is invalid or violates broker constraints.
- Stop-distance validity is deterministic and uses:
  - `RiskDistancePoints = Abs(ExpectedFill - PlannedStrategySL) / Point`
  - `MinStopDistancePoints` input (default `25`)
  - `BrokerMinStopPoints = max(SYMBOL_TRADE_STOPS_LEVEL, SYMBOL_TRADE_FREEZE_LEVEL)`
  - `RequiredMinStopPoints = max(MinStopDistancePoints, BrokerMinStopPoints)`
- If `RiskDistancePoints < RequiredMinStopPoints`, setup planning must publish `Ineligible` with stop-distance rejection.

### 7.5 Safeguard Stop for Virtual Entry (Emergency Layer)
- Applies only when `EntryExecutionMode = VirtualTrigger`.
- Purpose: emergency protection in extreme volatility beyond planned risk stop.
- Configurable controls:
  - `EnableSafeguardSL = true` (default `true`)
  - `SafeguardSLMultiplier` (default `2.0`)
- Definitions:
  - `PlannedStrategySL` = SL from selected `SLMode` (primary strategy stop).
  - `PlannedRiskDistance = Abs(Entry - PlannedStrategySL)`
  - `SafeguardDistance = SafeguardSLMultiplier * PlannedRiskDistance`
- Safeguard broker SL:
  - Buy: `SafeguardSL = Entry - SafeguardDistance`
  - Sell: `SafeguardSL = Entry + SafeguardDistance`
- MT5 single-broker-stop handling:
  - Broker-level SL is set to `SafeguardSL` (when enabled).
  - Primary strategy SL remains internal/virtual (`PlannedStrategySL`) and EA closes trade when hit.
- If safeguard level cannot be placed due to broker constraints while enabled, skip trade.

## 8) Take Profit Rules
Take profit is model-based:
- `TPMode = FibNegExtension | RiskReward` (default `FibNegExtension`)

### 8.1 Fib Negative Extension TP (Default)
- `FibTargetLevel` is configurable with allowed values `{0.272, 0.618}` (default `0.272`).
- Bearish setup:
  - Anchor from `CorrectionHigh` to `ImpulseLow`
  - `TP = ImpulseLow - FibTargetLevel * (CorrectionHigh - ImpulseLow)`
- Bullish setup:
  - Anchor from `CorrectionLow` to `ImpulseHigh`
  - `TP = ImpulseHigh + FibTargetLevel * (ImpulseHigh - CorrectionLow)`

### 8.2 Risk-Reward TP (Optional)
- `TargetRR` is input-configurable (default `2.0`).
- Bullish: `TP = Entry + (TargetRR * RiskDistance)`
- Bearish: `TP = Entry - (TargetRR * RiskDistance)`
- Constraint: `TargetRR >= MinRR`

## 9) Risk and Exposure Rules
- Risk per trade is configurable:
  - `RiskPercent` (default `1.0`)
  - `RiskBase = Equity | Balance | CalculatedBalance` (default `CalculatedBalance`)
- Maximum concurrent open risk is configurable:
  - `MaxConcurrentRiskPercent` (default `3.0`)
  - `ExposureBase = Equity | Balance | CalculatedBalance` (default `CalculatedBalance`)
- Position sizing is derived from entry-stop distance, tick value, and selected risk base.
- If lot size cannot be normalized to broker limits, skip trade.

## 10) Trade Management and Non-Goals
- Trade lifecycle: open until one of these events occurs:
  - Take profit hit
  - Strategy stop hit (virtual or broker-managed)
  - Safeguard stop hit (if enabled)
  - Break-even risk-free exit (Section `10.1`, if enabled)
- No martingale.
- No grid.
- No averaging down.
- No pyramiding.
- No discretionary/manual overrides in decision logic.

### 10.1 Break-Even Risk-Free Management
Break-even management is configurable and default-enabled.

Active runtime note:
- Break-even remains part of the full strategy contract.
- It is part of the active `MOHY_DebugEA` / `MOHY_TradeEA` runtime for both supported entry modes.
- Phase-four live execution applies:
  - virtual/internal break-even for `VirtualTrigger`
  - broker `SL` migration to net-zero break-even for `RealPendingOrder`

- Enable flag:
  - `EnableBreakEvenOnImpulseExtreme = true` (default `true`)
- Trigger reference level is fixed to `H1` impulse extreme:
  - Sell trade: trigger when price reaches `H1ImpulseLow`
  - Buy trade: trigger when price reaches `H1ImpulseHigh`
- Trigger condition:
  - Immediate activation on touch (no close confirmation required).

Net-zero break-even price definition (includes costs):
- Break-even level is computed to target zero net PnL after spread/commission costs.
- `BreakEvenMode = NetZeroIncludingCosts` (selected behavior)
- Side-specific net-zero exit quotes:
  - Buy: `BreakEvenNetBid = EntryAsk + NetCostPoints`
  - Sell: `BreakEvenNetAsk = EntryBid - NetCostPoints`

Mode-specific execution behavior:
- If `EntryExecutionMode = VirtualTrigger`:
  - Use virtual/internal break-even (no broker SL move to BE).
  - If price returns to net-zero BE level, close trade immediately at market.
- If `EntryExecutionMode = RealPendingOrder`:
  - Move broker SL to net-zero BE level.
  - Let broker SL handle the risk-free exit.

Broker stop-level guard for real-mode BE move:
- If broker rules block moving SL to BE:
  - Retry BE move for `BERetryTicks` attempts (default `5`).
  - If still blocked after retries, close trade at market.

### 10.2 Configurable Post-BE Management (Trail / Partials / Hybrid)
Post-entry management after break-even can be fully configured.

Active runtime note:
- This section is now part of the active `MOHY_DebugEA` / `MOHY_TradeEA` runtime.
- Phase-four implementation must remain deterministic, restart-recoverable, and mode-coupled.

Management profile:
- `PostBEManagementProfile = Off | TrailOnly | PartialOnly | Hybrid` (default `Hybrid`)

Activation timing:
- `PostBEStartMode = Immediate | AfterBreakEven | AtRMultiple` (default `AfterBreakEven`)
- If `PostBEStartMode = AtRMultiple`, use `PostBEStartR` (input).
- If `EnableBreakEvenOnImpulseExtreme = false` while `PostBEStartMode = AfterBreakEven`, post-BE management remains inactive until start mode is changed.
- `AtRMultiple` activation formula:
  - `InitialRiskDistance = Abs(Entry - InitialStrategySL)`
  - Buy: `OpenR = (Bid - Entry) / InitialRiskDistance`
  - Sell: `OpenR = (Entry - Ask) / InitialRiskDistance`
  - management starts when `OpenR + Eps >= PostBEStartR`
- If multiple management actions are simultaneously eligible on the same tick, apply them in deterministic order:
  1. break-even activation
  2. post-BE start activation
  3. partial execution
  4. stop action routed by the partial result
  5. trailing update
- The active protection level after any management cycle is the tightest valid risk-reducing stop candidate; the runtime must never loosen protection to satisfy a later rule.

#### 10.2.1 Trailing Stop Module
Trail module is selectable and can be enabled by profile.

Trail model:
- `TrailModel = FixedPoints | ATRBased | StructureBased | MABased` (default `StructureBased`)
- `TrailModelSelectEnabled = true` (input-based model selection)

Deterministic trail formulas:
- `FixedPoints`:
  - Buy: `TrailCandidate = Bid - TrailFixedPoints * Point`
  - Sell: `TrailCandidate = Ask + TrailFixedPoints * Point`
- `ATRBased`:
  - `TrailATR = ATR(M15, TrailATRPeriod, shift=1)`
  - `TrailDistance = TrailATRMultiplier * TrailATR`
  - Buy: `TrailCandidate = Bid - TrailDistance`
  - Sell: `TrailCandidate = Ask + TrailDistance`
- `StructureBased`:
  - Buy: use confirmed `M15` swing low by `TrailStructureSwingIndex` (`1` = latest)
  - Sell: use confirmed `M15` swing high by `TrailStructureSwingIndex` (`1` = latest)
- `MABased`:
  - Inputs:
    - `TrailMAPeriod` (default `20`)
    - `TrailMAMethod` (default `EMA`)
    - `TrailMAPrice` (default `Close`)
    - `TrailMABufferPoints` (default `0`)
  - `TrailMA = MA(M15, TrailMAPeriod, TrailMAMethod, TrailMAPrice, shift=1)`
  - Buy: `TrailCandidate = TrailMA - TrailMABufferPoints * Point`
  - Sell: `TrailCandidate = TrailMA + TrailMABufferPoints * Point`

Trail update cadence:
- `TrailUpdateCadence = EveryTick | LTFClose | HybridIntrabar` (default `HybridIntrabar`)
- `HybridIntrabar` means:
  - update/tighten intrabar only when a new favorable extreme is formed
  - do not loosen during adverse oscillation

Trail strictness:
- `TrailOneWayRatchet = true` (default `true`)
- Stop can only move in the risk-reducing direction (never loosen).
- Final candidate is clamped to executable-side safety:
  - Buy stop cannot be above `Bid - 1*Point`
  - Sell stop cannot be below `Ask + 1*Point`

#### 10.2.2 Partial Take-Profit Module
Partial module is selectable and can be enabled by profile.

Partial model:
- `PartialModel = RMultiple | FibLevels | Selectable` (default `RMultiple`)

Partial leg target inputs (`1..3` legs in current implementation scope):
- `PartialRMultiple1..3`
- `PartialFibLevel1..3`
- `PartialTargetMode1..3 = RMultiple | FibLevel` (used only when `PartialModel = Selectable`)

Partial count and sizing:
- `PartialCount` is input-configurable (`1..3`, default `2`)
- Active partial percents (`PartialPercent1..PartialPercentN`) must sum to `100%` (tolerance `+/- 0.01`)

Default balanced partial template (used unless overridden):
- `PartialCount = 2`
- `PartialPercents = {50, 50}`

Deterministic leg target formulas:
- Common:
  - `InitialRiskDistance = Abs(Entry - InitialStrategySL)`
- `RMultiple`:
  - Leg `i` target distance: `PartialRMultiple_i * InitialRiskDistance`
  - Buy: `TargetPrice_i = Entry + distance`
  - Sell: `TargetPrice_i = Entry - distance`
- `FibLevels`:
  - Uses continuation anchors from setup context:
    - `ImpulseHigh = max(ImpulseOrigin, ImpulseExtreme)`
    - `ImpulseLow = min(ImpulseOrigin, ImpulseExtreme)`
    - `CorrectionHigh`, `CorrectionLow` from accepted retracement window
  - Buy: `TargetPrice_i = ImpulseHigh + PartialFibLevel_i * (ImpulseHigh - CorrectionLow)`
  - Sell: `TargetPrice_i = ImpulseLow - PartialFibLevel_i * (CorrectionHigh - ImpulseLow)`
- `Selectable`:
  - For each leg `i`, resolve target by `PartialTargetMode_i`:
    - `RMultiple`: use `PartialRMultiple_i` formula
    - `FibLevel`: use `PartialFibLevel_i` formula

Stop action after each partial:
- `PostPartialStopAction = Keep | MoveToBEorBEPlus | MoveToStructure | ApplyTrailNow` (default `MoveToBEorBEPlus`)
- `PostPartialBEPlusPoints` is input-configurable (default `0`)
- Deterministic action routing:
  - `Keep`: no stop change
  - `MoveToBEorBEPlus`:
    - Buy: move stop to `BreakEvenLevel + PostPartialBEPlusPoints * Point`
    - Sell: move stop to `BreakEvenLevel - PostPartialBEPlusPoints * Point`
  - `MoveToStructure`:
    - Buy: move stop to latest confirmed `M15` swing low by `TrailStructureSwingIndex`
    - Sell: move stop to latest confirmed `M15` swing high by `TrailStructureSwingIndex`
    - If no valid structure candidate exists, skip action and log `BlockedByGuard`
  - `ApplyTrailNow`:
    - Immediately compute stop using selected `TrailModel` and apply once
    - If computed stop is invalid/unavailable, skip action and log `BlockedByGuard`

Final target behavior with partials:
- `RunnerTargetMode = KeepExistingTP | TrailOnlyRunner` (default `KeepExistingTP`)
- `KeepExistingTP`: keep original TP for remaining runner size.
- `TrailOnlyRunner`:
  - After first successful partial execution, remove TP for remaining runner (`TP = 0`)
  - Remaining runner exits are stop-driven only (break-even/trailing/virtual stop behavior per execution mode)
  - If TP removal fails under broker constraints, use management retry/fallback policy.

#### 10.2.3 Execution Mode Coupling
Management action routing is mode-dependent:
- If `EntryExecutionMode = VirtualTrigger`:
  - partial exits, trailing, and stop state are managed virtually/internal by EA
- If `EntryExecutionMode = RealPendingOrder`:
  - partial exits and SL updates are managed via broker order modifications

#### 10.2.4 Filters and Failure Handling
Execution filters:
- Spread/slippage filters used for entry are also applied to management actions by default:
  - `ApplyExecFiltersToManagement = true`

Failure behavior:
- If partial close or SL modification fails due to broker constraints:
  - retry up to `ManagementRetryCount` attempts
  - if still failing, fallback action is market-close of intended managed size/state
  - `ManagementFailFallback = RetryThenMarketClose` (default)
- Anchor-dependent management actions (fib-target partials) require valid anchor context from setup formation.
  - If anchors are unavailable (for example after restart recovery), skip the anchor-dependent action and emit explicit `BlockedByGuard` management log/audit evidence.

#### 10.2.5 Balanced Defaults Profile
Balanced defaults for post-BE management:
- `PostBEManagementProfile = Hybrid`
- `PostBEStartMode = AfterBreakEven`
- `TrailModel = StructureBased`
- `TrailUpdateCadence = HybridIntrabar`
- `TrailOneWayRatchet = true`
- `PartialModel = RMultiple`
- `PartialCount = 2`, `PartialPercents = {50, 50}`
- `PostPartialStopAction = MoveToBEorBEPlus`
- `RunnerTargetMode = KeepExistingTP`
- `ApplyExecFiltersToManagement = true`
- `ManagementFailFallback = RetryThenMarketClose`

## 11) Execution and Determinism Requirements
- Signal discovery/validation logic (impulse, retracement, continuation) uses closed-candle values from `M15` and `H1` (`shift >= 1`).
- The canonical kernel object graph (`Candle -> PivotPoint -> Element -> Leg -> Swing3 -> PatternSemantic`) is the only allowed source for structural/semantic facts.
- Modules are not allowed to bypass kernel objects and recompute separate swing streams from raw candles.
- `VirtualTrigger` entry triggering is closed-`M15` only and uses the close-cross rule from Section `6.3`.
- `RealPendingOrder` fill timing remains broker-driven and can occur intrabar.
- Post-confirmation execution monitoring can run intrabar/tick-level for:
  - pre-entry invalidation touches
  - pending-order monitoring/modification
  - spread/slippage checks
  - break-even, trailing, partials, and virtual stop management
- Identical history + identical inputs must produce identical signals and trades.

## 12) Market Suitability (Guidance)
Best used on liquid, lower-spread instruments (for example major FX pairs and high-liquidity crypto CFDs where available). Avoid low-liquidity or consistently wide-spread symbols.


