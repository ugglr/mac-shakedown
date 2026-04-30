# Target presets

Each `*.json` in this folder is a preset spec for a specific Mac SKU. When the agent runs the QA, you can specify a target preset to skip the manual config dialogue:

```bash
claude "run QA against target mbp-16-m5-max-64"
```

The agent loads the JSON, asserts against the unit, and references the preset's `calibration_dir` for known issues.

If your config isn't here, either:
- Run without a target and the agent will ask you for chip / RAM / chassis interactively, or
- Add a new preset (see [CONTRIBUTING.md](../CONTRIBUTING.md#adding-a-target-preset))

## Schema

```json
{
  "name": "MacBook Pro 16-inch — M5 Max — 64 GB",
  "chip_pattern": "M5 Max",
  "memory_gb": 64,
  "model_must_include": "16",
  "calibration_dir": "examples/m5-2026",
  "thermal_chassis_class": "active-cooled-pro"
}
```

`thermal_chassis_class` values:

| Class | Examples | Sustained-load expectation |
|---|---|---|
| `fanless` | MacBook Air | Throttles hard by design — looser thresholds |
| `active-cooled-pro` | MacBook Pro 14"/16" | Should hold steady — strict thresholds |
| `desktop` | Mac mini, Mac Studio, iMac | Massive headroom — strictest thresholds |
