# MOHY Visualizer UI Specification (MT5)

Date: 2026-03-17

## 1) Scope
This spec defines read-only chart visualization behavior for:
- `Indicators/MOHY_Visualizer.mq5`

This spec also defines the active phase-five execution control-plane surface for:
- `Experts/MOHY_DebugEA.mq5`
- `Experts/MOHY_TradeEA.mq5`

The visualizer must not open/modify/close trades.

## 2) Timeframe, Pair, and Render-Scope Rules
- Allowed HTF/LTF pairs: `H1/M15`, `H2/M30`, `H4/H1`, `D1/H4`.
- Pair invariant: `HTF` is strictly higher than `LTF` and must match one of the allowed pairs.
- Chart timeframe is non-authoritative for kernel semantics.
- Visual history window is chart-anchored:
  - `LookbackBars` defines one authoritative visible-history window on the current chart timeframe.
  - every kernel snapshot used by the visualizer must map that single chart-time window into its own source timeframe before building facts.
  - mixed-timeframe overlays must therefore cover the same visible time span even when their source timeframe differs (`HTF` impulse on `LTF` chart, `LTF` correction on `HTF` chart, etc.).
- `RenderScope` behavior:
  - `PairOnly`: render only when chart timeframe is exactly configured `HTF` or `LTF`.
  - `Auto`: render timeframe is snapped by chart-timeframe relation to the configured pair.
  - `ChartNative` (default): render directly on current chart timeframe.
- History mode behavior:
  - `CurrentPotentialOnly`: lifecycle-focus mode. Start from the selected lifecycle's linked `PotentialImpulse.begin_time`, not correction begin.
  - in `CurrentPotentialOnly`, the visualizer must resolve runtime scope read-only from symbol + configured pair + `RuntimeMagicNumber`, join to `lifecycle_state.csv` when available, and otherwise fall back deterministically to kernel lineage.
  - in `CurrentPotentialOnly`, lifecycle end must use actual runtime resolution time when available; otherwise it must use deterministic kernel termination for waiting/open/pre-entry-invalidation contexts.
  - `LookbackHistory`: render all published drawings/facts that fall inside the authoritative `LookbackBars` window.

## 3) Rendering Responsibilities
- Build kernel snapshots with provisional stream enabled (`include_provisional_latest=true`).
- Provisional publication lock: visualizer/runtime must treat provisional publication as always-on and must not provide a runtime path that disables it.
- Keep history scope deterministic:
  - `LookbackBars` is the only public history-depth control.
  - legacy per-overlay history caps/filters must not independently widen or shrink history relative to `LookbackBars`.
- Render confirmed and provisional peak/valley points.
- Render optional leg lines between alternating points.
- Render pattern ribbon segments from kernel `Swing3` semantics.
- Render potential impulse lines when enabled.
- Render potential correction lines when enabled.
- Apply one shared lifecycle `[start,end]` filter across peak/valley, ribbon, impulse, correction, continuation, setup-plan, and focused historical-setup overlays in `CurrentPotentialOnly`.
- Render compact status block with:
  - chart timeframe,
  - configured pair,
  - render timeframe,
  - pivot totals and confirmed/live split,
  - current pattern,
  - current breakout state/certainty,
  - selected `PotentialImpulse` state,
  - selected `PotentialCorrection` lifecycle state.

## 4) Potential-Impulse Rendering Contract
- Source timeframe selection is configurable by `PotentialImpulseRenderMode`:
  - `HtfOnly`
  - `HtfOnHtfLtf` (default)
  - `AnyTfGteHtf`
  - `ChartTimeframe`
- Indicator inputs map directly into kernel detection config for:
  - swing close-break gate,
  - leg close-break gate,
  - directional candle policy and doji epsilon.
- Default directional exception policy is:
  - `PotentialImpulseAllowAnyOppositeBeforeLegBreakout = true`.

## 5) Potential-Correction Rendering Contract
- Correction lines are rendered only from `snapshot.potential_corrections`.
- Active correction selection is deterministic:
  - latest by smallest `begin_shift` (tie: newer `begin_time`).
- Kernel publishes correction anchor families:
  - `reference` anchors for decision semantics and correction-state math.
  - `visual` anchors for chart geometry projection.
- Visualizer must draw correction begin geometry from kernel `visual` anchors and use deterministic fallback to `reference` anchors when visual anchors are unresolved.
- `visual` correction begin must align with the linked potential-impulse end extreme projection on execution timeframe (same deterministic matching family used by impulse endpoint projection).
- Active runtime policy: correction `visual` begin and `reference` begin are expected to be identical.
- In `SinglePath` mode, correction end geometry must use the published correction extreme endpoint (`fact.end_*`) for both active and historical facts.
- Render mode:
  - `SinglePath` (default): one correction line per fact.
  - `StateSegments`: split by `Forming`, `Confirmed`, and `Invalidated`.
- History-mode behavior:
  - in `LookbackHistory`, correction history must be rendered from kernel-published facts inside the authoritative `LookbackBars` window without any separate per-overlay history cap.
  - in `CurrentPotentialOnly`, the visualizer must render only the selected lifecycle-linked correction context, keyed by runtime lineage when available.
- Trade setup history behavior:
  - when historical setup replay is enabled, the visualizer must render all published historical setup outcomes inside `LookbackBars` in `LookbackHistory`.
  - `CurrentPotentialOnly` must suppress broad historical replay, but it may render exactly one lifecycle-matched historical setup outcome when that outcome is the authoritative focused lifecycle.
  - historical setup rendering must consume kernel-published setup replay facts only.
  - the visualizer must not infer missed/entered/stopped/target-hit outcomes from raw chart candles on its own.
  - the first historical setup overlay pass renders deterministic execution outcomes limited to `Missed`, `Entered`, `TargetHit`, `StopHit`, and `Open`.
- Kernel-gating defaults exposed in visualizer inputs:
- `PotentialCorrectionSupersedeDirectionMode = OppositeOnly`.
- `PotentialCorrectionSupersedeScope = FormingAndConfirmed`.

## 6) Object Naming and Cleanup
- Object prefix pattern: `MOHY_VIZ_<ChartID>_GEN_...`
- Indicator must delete only its own prefixed objects on refresh/deinit.

## 7) State Visibility and Determinism
- Confirmed vs provisional state must remain explicit in text/tooltip surfaces.
- Any provisional marker must be deterministic and reproducible on rerun.
- Tick-driven refresh is allowed.
- Prefer object upsert/update over unnecessary full recreation where possible.

## 8) EA Phase-five Panel
- `MOHY_DebugEA` / `MOHY_TradeEA` phase five exposes the active chart control plane for the runtime.
- Panel responsibilities:
  - show symbol and configured timeframe pair
  - show EA mode (`VirtualTrigger` or `RealPendingOrder`)
  - show pause state
  - show selected setup state
  - show selected `setup_key` and `impulse_id`
  - show selected potential-impulse state (`Live` or `Confirmed` plus breakout summary)
  - show selected potential-correction lifecycle state (`Forming`, `Confirmed`, or `Invalidated`)
  - show current position state (`None`, `Open`, `Recovered`, `Blocked`)
  - show current waiting trigger state, including pending-order ticket visibility when applicable
  - show break-even state (`Disabled`, `Open`, `Armed`, `RiskFree`, `Recovered`)
  - show post-BE profile (`Off`, `TrailOnly`, `PartialOnly`, `Hybrid`)
  - show trailing state (`Off`, `PendingStart`, `Active`, `BlockedByGuard`)
  - show partial progress state as deterministic executed-percent summary
  - show confirmation/cooldown state for dangerous actions
  - show last management action result
  - show last action result
- Enabled actions:
  - `Pause`
  - `Resume`
  - cancel waiting entry
  - close strategy trades
  - emergency flatten
- Behavior:
  - `Pause` and `Resume` are immediate control-plane actions.
  - `Pause` blocks new entries and new waiting-state activation.
  - if a broker pending order is already active for the current waiting setup, `Pause` must suspend that waiting entry by deleting the pending order while keeping the waiting-state context recoverable for later resume.
  - `Pause` must not interfere with an already open broker trade.
  - open-trade break-even monitoring remains active while entries are paused.
  - `Resume` allows the EA to resume waiting-state ownership and, when the same setup is still authoritative, re-place the broker pending order in `RealPendingOrder` mode.
  - dangerous actions (`Cancel Waiting`, `Close Strategy Trades`, `Emergency Flatten`) require deterministic two-step confirmation using the runtime cooldown/expiry window.
  - every UI action must produce deterministic audit evidence when file audit is enabled:
    - intent
    - confirmation or expiry
    - outcome
    - pre-state hash
    - post-state hash
    - result code / broker error
  - terminal alerts are runtime-configurable and must emit only on state change / action outcome transitions rather than on every tick.
  - if multiple MOHY positions are detected for the same symbol/scope, the panel must surface a critical blocked state and the EA must disable new entries until manual cleanup.
