# MOHY Config Profiles Workflow (MT5)

Date: 2026-02-24

## 1) Source of Truth
Editable registry:
- `config/registry/profiles.json`

## 2) Registry Sections
- `default`: shared baseline keys
- `pairs`: symbol-level overrides
- `experiments`: experiment overlays
- `indicator_inputs`: visualizer input overrides

Recommended indicator input key format:
- `MOHY_Visualizer.<InputName>`

## 3) Generation Commands
Generate runtime config artifacts:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/config/generate_runtime_profiles.ps1
```

Generate visualizer preset set files:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/config/generate_tester_sets.ps1
```

## 4) Generated Outputs
- `Files/MOHY/config/default.ini`
- `Files/MOHY/config/pairs/*.ini`
- `Files/MOHY/config/experiments/*.ini`
- `Files/MOHY/config/indicators/*.ini`
- `Files/MOHY/config/indicator_inputs.ini`
- `Presets/MOHY/*.set`
- `tools/config/manifest.csv`

## 5) Guardrail
Do not hand-edit generated files under:
- `Files/MOHY/config/`
- `Presets/MOHY/`
- `tools/config/manifest.csv`
