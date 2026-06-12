# MOHY Playground

Persistent workspace for visual collaboration, artifact inspection, and kernel-debug communication.

## Main entry
- Viewer: `playground/viewer/index.html`

## Structure
- `playground/viewer/`: browser viewer UI.
- `playground/examples/`: curated static examples for explanation/training.
- `playground/schemas/`: versioned artifact schemas.
- `playground/artifacts/runs/`: runtime-generated artifacts (gitignored except `.gitkeep`).
- `playground/artifacts/samples/`: optional curated artifacts kept in git.
- `playground/tools/`: helper notes/scripts for exporting/importing artifacts.

## Open the viewer
- Double-click `playground/viewer/index.html`.
- Or open it in Chrome/Edge/Firefox directly.
- The viewer includes an **Assistant Explanation** panel under the chart.
- Explanation source priority is:
  1. manually loaded explanation override file (`.md/.html/.txt`)
  2. artifact-embedded explanation fields

## Artifact format
- Current schema: `playground/schemas/mohy_snapshot_artifact_v2.schema.json`
- Required top-level arrays:
  - `candles`, `elements`, `legs`, `swings3`,
    `potential_impulses`, `potential_corrections`, `potential_continuation_signals`, `trade_setup_plans`
- `potential_continuation_signals` are structural-only confirmation artifacts and should expose broken-level/signal anchors rather than executable entry anchors.
- `trade_setup_plans` are the primary execution-facing layer for viewer/debug discussions.
- Optional explanation fields:
  - preferred: `explanation = { title, format, content }`
  - backward-compatible: `explanation_markdown` / `explanation_html` / `explanation_text`
- Viewer compatibility:
  - `schema_version=1.0` artifacts still load when they use legacy continuation `entry_*` anchors.

## Workflow
1. Generate or collect a run artifact JSON.
2. Place it under `playground/artifacts/runs/` (or anywhere local).
3. Open the viewer and load the JSON with file input.
4. Toggle layers and inspect shape/anchors with the team.

## Scope guard
This playground is read-only analysis/communication tooling. It must not become a second strategy brain.
