# MOHY Playground Operating Guide

Date: 2026-02-27

## 1) Purpose
`playground/` is a persistent, repo-tracked visual collaboration workspace for:
- explanation visuals between developer/agent and user,
- artifact inspection from kernel snapshots,
- debug communication over deterministic exported data.

The playground is read-only analysis tooling. It is not a strategy execution module.

## 2) Location and Layout
- `playground/viewer/`: browser UI (`index.html`) for rendering artifacts.
- `playground/examples/`: small curated examples for deterministic explanations.
- `playground/schemas/`: versioned artifact schemas.
- `playground/artifacts/runs/`: generated local run artifacts (gitignored by default).
- `playground/artifacts/samples/`: curated artifacts optionally committed.
- `playground/tools/`: exporter/importer helper notes/scripts.

## 3) Artifact Contract
Current schema:
- `playground/schemas/mohy_snapshot_artifact_v2.schema.json`

Versioning rules:
1. Keep `schema_version` explicit in each artifact.
2. Backward-incompatible changes require a new schema file/version.
3. Viewer changes must preserve old schema compatibility where practical.

Current v2 contract notes:
- `potential_continuation_signals` are structural-only confirmation artifacts and should publish broken-level/signal anchors rather than executable `entry_*` anchors.
- `trade_setup_plans` is the execution-facing artifact array for entry/stop/target discussion.

Minimum traceability fields:
- `run_id`
- `symbol`
- `timeframe`
- `context_timeframe`
- `execution_timeframe`
- `built_at`
- `config_hash` (when available)

Recommended explanation payload (for assistant-to-user communication):
- `explanation = { title, format, content }`
  - `format`: `markdown | html | text`
  - `content`: explanation body rendered in viewer panel
- Legacy compatibility fields are also accepted:
  - `explanation_markdown`, `explanation_html`, `explanation_text`

## 4) Normal Workflow
1. Generate an artifact from MT5 (or synthetic/test source).
2. Save it under `playground/artifacts/runs/<run_id>.json`.
3. Open `playground/viewer/index.html` in browser.
4. Load artifact and inspect layers (`candles/elements/legs/swings3/potential_* / trade_setup_plans`).
5. Read/discuss the Assistant Explanation panel rendered from artifact explanation fields.
6. Optionally load a temporary explanation override file (`.md/.html/.txt`) for ad-hoc discussion.
7. Keep only durable references/examples in `samples/` and docs.

## 5) Scope Guardrails
- Do not move strategy detection/decision logic into the playground.
- Do not treat playground outputs as authoritative runtime signals.
- Kernel contracts and `docs/strategy.md` remain normative for trading behavior.

## 6) Relationship to Existing Debug Exports
Window-debug CSV exports can continue for matrix/debug workflows.
If a visualization discussion is needed, convert/export equivalent run data into playground artifact JSON and inspect in viewer.
