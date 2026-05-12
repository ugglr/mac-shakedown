# Target presets

Each `*.json` in this folder is a preset spec for a specific Mac SKU. Pass it to `./run` to assert the unit matches:

```bash
./run --target mbp-16-m5-max-64
```

`./run` loads the JSON, asserts chip / memory / model substrings against the unit, and references the preset's `calibration_dir` for known issues.

If your config isn't here, either:
- Run without `--target` — chassis class auto-detects, the SKU asserts are skipped, but the variance / thermal / battery checks still run, or
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
| `fanless` | Apple Silicon MacBook Air | Throttles hard by design — looser thresholds |
| `active-cooled-pro` | Apple Silicon MacBook Pro 14"/16" | Should hold steady — strict thresholds |
| `desktop` | Apple Silicon Mac mini / Studio / iMac | Massive headroom — strictest thresholds |
| `intel-laptop` | Intel MacBook Pro / Air | Throttles hard — pre-Apple-Silicon thermals are aggressive |
| `intel-desktop` | Intel iMac / Mac mini | Decent headroom but tighter than Apple Silicon desktop |

## Generation coverage

| Generation | Status |
|---|---|
| Apple M5 (2026) | ✅ primary calibration ([`examples/m5-2026/`](../examples/m5-2026/)) |
| Apple M1 / M2 / M3 / M4 | 🟡 scripts work, no per-generation calibration yet — add one when needed |
| Intel (2018+) | 🟡 scripts work with `intel-laptop` / `intel-desktop` chassis classes; defect classes are different (T2, butterfly keyboards, GPU stutter) and warrant a separate calibration folder |
| Pre-2018 Intel | 🔴 untested — `powermetrics` output format may differ; YMMV |

For the older non-M5 generations the verification methodology (variance, thermal saturation, manual checks) transfers cleanly — only the *thresholds* and *known-defect lookup* need per-generation tuning. PRs welcome to add new calibrations under `examples/<generation>-<year>/`.
