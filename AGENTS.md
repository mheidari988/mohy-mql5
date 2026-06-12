# AGENTS Instructions for MOHY MQL5

## Scope
- These instructions apply to this `mohy-mql5` repository.
- This repository contains the MT5/MQL strategy implementation, indicators, EAs, configs, presets, verification scripts, and strategy reference docs.
- The sibling `mohy-platform` repository contains the C#/.NET platform, ASP.NET backend, React workstation, schemas, and deployment runtime. Do not implement platform code here.
- Focus on MT5 docs and implementation for:
  - `docs/strategy.md`, `docs/architecture.md`, `docs/development_operating_model.md`
  - `Include/MOHY/Core/*`
  - `Include/MOHY/Runtime/*`
  - `Indicators/MOHY_Visualizer.mq5`
  - `Experts/MOHY_DebugEA.mq5`
  - `Experts/MOHY_TradeEA.mq5`
- Ignore legacy or out-of-scope work unless explicitly requested:
  - `Experts/MOHY_EA.mq4`
  - `Indicators/MOHY_PivotsLegs.mq4`
  - `Indicators/MOHY_HtfImpulseQualified.mq4`
  - `helper-tools/ConfigStudio/*`
  - `helper-tools/ToolLauncher/*`

## Strategy Authority
- `docs/strategy.md` is the single source of truth for trading behavior.
- If code and docs disagree, update code to match `docs/strategy.md`.
- Normalize new strategy notes into `docs/strategy.md` before implementation.
- Do not add undocumented strategy rules or rely on non-MOHY platform examples unless explicitly requested.
- When C# platform work needs parity context, inspect this repo as reference from `mohy-platform`; keep platform implementation in the sibling repo.

## Documentation Budget
- Default to code inspection first, then open only the relevant doc section found with `rg`.
- Do not read or update every companion doc for routine bug fixes, refactors, compile fixes, or local implementation work.
- Update docs only when the change alters strategy behavior, module ownership, runtime/control-plane contracts, public config, verification commands, or the active roadmap.
- For strategy behavior changes, update the exact `docs/strategy.md` section before implementation.
- For architecture or UI ownership changes, update `docs/architecture.md` or `docs/ui-spec.md` only where the contract actually changes.
- Do not maintain phase-ledger or status-matrix Markdown files for completed work; use concise handoff context instead.

## Non-Negotiable Strategy Invariants
- Strategy scope is MOHY continuation only.
- The configured HTF/LTF pair is authoritative; default `H1/M15`; allowed pairs are `H1/M15`, `H2/M30`, `H4/H1`, `D1/H4`; `HTF` must be exactly `4x` `LTF`.
- The kernel must recompute every tick and publish both confirmed and provisional facts.
- A setup is eligible only when confirmed LTF continuation exists on the selected execution timeframe and retracement acceptance passes the documented Fibonacci bounds.
- Before entry, invalidate the setup if price reaches the selected HTF impulse extreme threshold.
- After entry, reaching the selected HTF impulse extreme must trigger the documented break-even or risk-free handling.
- Post-entry management modes `Off`, `TrailOnly`, `PartialOnly`, and `Hybrid` must stay configurable and follow `docs/strategy.md`.
- Allow only one active trade per impulse structure.
- Risk and exposure inputs must follow `docs/strategy.md`, including `RiskPercent`, `RiskBase`, `MaxConcurrentRiskPercent`, and `ExposureBase`.
- Never add martingale, grid, averaging-down, discretionary overrides, invalid stop sizing, or trades below the documented minimum reward-to-risk.

## Architecture and Layering
- `PriceActionKernel` and shared builders or classifiers are the only strategy orchestrators.
- Put detection and decision logic in shared core modules first; indicators, EAs, and tools should map inputs, call the kernel, and consume published facts.
- Do not duplicate correction ranking, selection, or candle-based decision logic in consumers; publish those facts from the kernel.
- Keep consumer `input` variables local, but map them into shared domain config structs before kernel execution.
- Keep the chart-drawn MT5 panel as the authoritative control plane unless explicitly re-decided, and do not allow runtime UI mutation of strategy rules.
- Visualization layers are read-only: they may style or project kernel facts, not invent or mutate them.
- Preserve clean separation between detection or publication, state semantics, and rendering.
- Avoid runtime file-config or shared-profile dependencies unless explicitly requested.

## Determinism and Artifacts
- Publish confirmation state explicitly so closed-candle versus provisional behavior is testable.
- Keep behavior deterministic across repeated backtests with the same data and inputs.
- Prefer explicit, testable formulas and parameters for ATR, efficiency or strength ratios, Fibonacci levels, and risk calculations.
- Preserve structured, versioned telemetry and artifacts; logging must not alter behavior.
- Use `playground/` for persistent visual collaboration and `temp/` for throwaway outputs.
- Version playground schemas under `playground/schemas/*`.
- Store run artifacts under `playground/artifacts/runs/` and include `schema_version`, `run_id`, `config_hash`, and symbol or timeframe context when available.
- If an artifact is meant to explain behavior visually, include the narrative in the payload.

## Docs and Verification
- Update docs first only when strategy behavior changes.
- Keep `docs/system_design_quick_read.md` and `docs/system_design_quick_read.drawio` in sync only when layer boundaries, module ownership, or runtime wiring change.
- Keep code changes scoped, testable by module, and compatible with existing compile scaffolding.
- Always run compile, syntax, or build gates for code changes.
- Run targeted verification for changed areas; reserve full matrices and determinism bundles for milestone/release closure or explicit requests per `docs/development_operating_model.md`.

## Session Handoff
- End every completed task with the short handoff format in `docs/session_handoff.md`.

## Repository Boundaries
- Public MQL source, strategy docs, examples, and deterministic verification scaffolding belong here.
- Private broker credentials, account history, terminal logs, compiled `.ex5` outputs, production secrets, and private research data do not belong in this repository.
- Keep Coolify, server, and production deployment docs out of this repo unless the user explicitly changes the private ops boundary.
