# Tools

This folder is for exporter/importer helpers.

Recommended first exporter target:
- MT5 script that serializes `CMohyPriceActionSnapshot` into the playground artifact schema.

Suggested output path:
- `playground/artifacts/runs/<run_id>.json`

Minimum traceability fields to include:
- `run_id`, `symbol`, `context_timeframe`, `execution_timeframe`, `built_at`, `config_hash`

No strategy decision logic should be implemented in exporter/importer helpers.
