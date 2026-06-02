# Target presets

Each `*.json` in this folder is a preset spec for a specific Mac SKU. Pass it to `./run` to assert the unit matches:

```bash
./run --target mbp-16-m5-max-64
```

`./run` loads the JSON, asserts chip / memory / model substrings against the unit, and references the preset's `calibration_dir` for known issues.

If your config isn't here, either:
- Run without `--target`: chassis class auto-detects, the SKU asserts are skipped, the variance / thermal / battery checks still run, or
- Add a new preset (see [CONTRIBUTING.md](../CONTRIBUTING.md#adding-a-target-preset))

## Schema

```json
{
  "name": "MacBook Pro 16-inch, M5 Max, 64 GB",
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
| `fanless` | Apple Silicon MacBook Air | Throttles hard by design, looser thresholds |
| `active-cooled-pro` | Apple Silicon MacBook Pro (generic / auto-detect) | Alias for the 16" thresholds; backward-compatible default |
| `active-cooled-pro-16` | Apple Silicon MacBook Pro 16" | Should hold steady, strict thresholds |
| `active-cooled-pro-14` | Apple Silicon MacBook Pro 14" | Throttles by design under sustained Pro load, looser steady-state / cliff bands |
| `desktop` | Apple Silicon Mac mini / Studio / iMac | Massive headroom, strictest thresholds |
| `intel-laptop` | Intel MacBook Pro / Air | Throttles hard, pre-Apple-Silicon thermals are aggressive |
| `intel-desktop` | Intel iMac / Mac mini | Decent headroom but tighter than Apple Silicon desktop |

Auto-detect (no `--target`) can't tell a 14" from a 16" (`system_profiler` doesn't expose screen size on Apple Silicon), so it uses the generic `active-cooled-pro`. Pass `--target mbp-14-...` on a 14" so its design throttling isn't read as a defect.

## Generation coverage

| Generation | Status |
|---|---|
| Apple M5 (2026) | ✅ primary calibration ([`examples/m5-2026/`](../examples/m5-2026/)) |
| Apple M1 (2020-2022) | ✅ calibration ([`examples/m1-2020/`](../examples/m1-2020/)) |
| Apple M2 (2022-2023) | ✅ calibration ([`examples/m2-2022/`](../examples/m2-2022/)) |
| Apple M3 (2023-2024) | ✅ calibration ([`examples/m3-2023/`](../examples/m3-2023/)) |
| Apple M4 (2024-2025) | ✅ calibration ([`examples/m4-2024/`](../examples/m4-2024/)) |
| Intel / T2 era (2016-2020) | ✅ calibration ([`examples/intel-2016/`](../examples/intel-2016/)); use the `intel-laptop` / `intel-desktop` chassis classes |
| Pre-2016 Intel | 🔴 untested; `powermetrics` output format may differ, YMMV |

For the older non-M5 generations the verification methodology (variance, thermal saturation, manual checks) transfers cleanly. Only the *thresholds* and *known-defect lookup* need per-generation tuning. PRs welcome to add new calibrations under `examples/<generation>-<year>/`.
