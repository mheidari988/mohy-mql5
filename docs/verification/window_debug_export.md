# Window Debug Export Workflow

## Goal
Create one reproducible CSV snapshot for a chart time window so issue triage can be done from data instead of screenshots only.

## Prompt Contract
When you write `debug` in a prompt, it means:
1. Use this workflow as the default debugging protocol.
2. First read `MQL5/Files/MOHY/debug_window/last_run_pointer.csv`.
3. Open the `csv_relative_path` from that pointer and debug that run/window.
4. If pointer/file is missing, ask you to run `WindowDebugExporter` once and then continue.

## Script
- `Scripts/MOHY/WindowDebugExporter.mq5`

## Minimal Manual Flow
1. Open the target chart and timeframe.
2. Draw two vertical lines around the issue window.
3. Select both vertical lines (recommended when chart has many lines).
4. Run `WindowDebugExporter` from MT5 Scripts.
5. Keep defaults unless you need overrides.
6. Share:
- `run_id` from script input/log (or auto generated one)
- exported CSV filename/path under `MQL5/Files/MOHY/debug_window`
- screenshot (optional) for visual anchor

If you do not send `run_id`, I can read:
- `MQL5/Files/MOHY/debug_window/last_run_pointer.csv`
This file is overwritten each run and points to the latest export.

## Window Resolution Priority
The script resolves start/end time in this order:
1. `StartLineName` + `EndLineName` inputs (if both set)
2. selected vertical lines (earliest selected = start, latest selected = end)
3. exactly two vertical lines on chart
4. manual times (`ManualWindowStart`, `ManualWindowEnd`)
5. all vertical lines min/max (only when `AllowAnyLinesFallback=true`)

## What Gets Exported
Single CSV with sections via `row_type`:
- `metadata`, `config`, `vline`
- `bar` (chart + kernel scopes)
- `element`, `leg`, `swing3`
- `potential_impulse`
- `potential_correction`
- `potential_continuation_signal`
- `trade_setup_plan`
- `potential_correction_timeline_full`
- `potential_correction_timeline_trimmed`
- `error` (if any scope fails)

Columns:
- `run_id, generated_at, row_type, scope, entity_id, in_window, time_from, time_to, payload`

`payload` is `key=value` pairs separated by `;`.

Config row notes:
- `config.entity_id` now exports as `strategy`
- config signature/hash includes setup-planning inputs that affect `TradeSetupPlan` publication, not only detection fields
- `potential_continuation_signal` payload is structural-only and exports continuation confirmation anchors (`BrokenLeg*`, `BrokenLevel*`, `Signal*`); executable entry/stop/target fields belong to `trade_setup_plan`
- correction, continuation, and trade setup rows also export kernel-owned selection fields (`IsSelected`, `SelectionRank`, linked correction recency metadata) so downstream viewers stay read-only

## Recommended Defaults
- `KernelDebugScope = MOHY_KERNEL_DEBUG_SCOPE_HTF_AND_LTF`
- `IncludeProvisionalLatest = true` (lock policy: effective behavior is always provisional-on)
- `ExportFactsOutsideWindow = true` for full forensic export

## Fast Triage Filters
- only window rows: `in_window=1`
- only corrections: `row_type=potential_correction`
- only impulses: `row_type=potential_impulse`
- only one timeframe scope: filter `scope` (for example `Kernel/M15`)
