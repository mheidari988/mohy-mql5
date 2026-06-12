# MOHY MQL5

`mohy-mql5` contains the MT5/MQL strategy implementation and reference material for MOHY.

This repository is intentionally separate from the deployable C#/.NET platform.

- MQL repo: `mohy-mql5`
- Platform repo: `mohy-platform`

## Start Here

- `AGENTS.md` - repository rules for MT5/MQL work.
- `docs/strategy.md` - trading behavior authority.
- `docs/architecture.md` - MT5/MQL module boundaries.
- `docs/development_operating_model.md` - verification and operating model.

## Directory Map

- `Experts/` - MOHY EAs.
- `Indicators/` - MOHY visualizer indicator.
- `Include/MOHY/` - shared MQL strategy core and runtime modules.
- `Files/MOHY/config/` - sample/default configuration inputs.
- `Presets/MOHY/` - MT5 preset files.
- `Scripts/MOHY/` - verification and export scripts.
- `docs/` - strategy, architecture, and verification notes.

## Boundary

Use this repo for MT5 strategy behavior, deterministic MQL verification, and MetaTrader reference work. Use `mohy-platform` for C# engine/runtime, ASP.NET backend, React workstation, Docker/Coolify runtime, and deployment work.

Do not commit broker credentials, account history, terminal logs, compiled outputs, private research data, or production secrets.

## Public Data Posture

Checked-in configs, presets, docs, and verification fixtures are intended to be sample/reference material. Real terminal accounts, broker credentials, logs, account history, compiled `.ex5` outputs, and private research results should stay outside this repository.

## License

This repository is released under the MIT License. See `LICENSE`.
