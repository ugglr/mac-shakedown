# Report Schema

Every QA run produces two artifacts in `Reports/`:

- **`<ISO-timestamp>.json`** — canonical machine-readable report. Stable, versioned schema. *This is what gets submitted to the future aggregator.*
- **`<ISO-timestamp>.md`** — human-readable render of the JSON.

## Top-level fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema_version` | string | yes | Semver of the schema. Currently `"1.0"`. |
| `shakedown_version` | string | yes | Tool version that produced the report (e.g. `"0.2.0"`). |
| `timestamp` | string | yes | ISO 8601 UTC. |
| `illustrative` | bool | no | `true` for hand-crafted samples (under `examples/sample-report-*`). Aggregator must filter these out. |
| `illustrative_note` | string | no | Companion to `illustrative: true`. |
| `target` | object | yes | The target preset / spec the run asserted against. See [target presets](../targets/README.md). |
| `unit` | object | yes | The actual unit's hardware identity (collected by `inventory.sh`). |
| `phases` | object | yes | One key per phase (see Phase shape). |
| `result` | string | yes | `"PASS"` / `"FAIL"`. |
| `result_reason` | string | yes | One-line summary. |
| `submission_safe` | bool | yes | Agent's assertion that no PII is present. |
| `store_location` | string\|null | no | Opt-in only. |
| `purchase_date` | string\|null | no | Opt-in only. |

## `unit` object — for cross-machine comparison

This is what the aggregator groups on for per-SKU baselines.

| Field | Type | Notes |
|---|---|---|
| `model` | string | e.g. `"MacBook Pro"` |
| `model_identifier` | string | e.g. `"Mac17,1"` |
| `chip` | string | e.g. `"Apple M5 Max"` (Apple Silicon) or `"Intel Core i7"` (Intel) |
| `is_apple_silicon` | bool | true if `chip_type` was reported by `system_profiler` |
| `perf_cores` | int | P-cores on Apple Silicon, all physical cores on Intel |
| `efficiency_cores` | int | E-cores on Apple Silicon, 0 on Intel |
| `logical_cpus` | int | Includes hyperthreading on Intel |
| `memory_gb` | int | rounded |
| `macos_version` | string | e.g. `"macOS 16.3 (Tahoe)"` |
| `kernel_version` | string | e.g. `"Darwin 26.3.0"` |
| `serial_hash` | string | `"sha256:<hex>"` — hashed by `inventory.sh`. The plaintext serial is **not** stored unless `INCLUDE_PLAINTEXT_SERIAL=1` was set. |

## Each phase's shape

Every entry in `phases` follows the same shape:

```json
"<n>_<name>": {
  "verdict": "pass" | "warn" | "fail" | "skipped",
  "duration_s": <int>,
  "details": { …phase-specific… },
  "verdict_reasons": ["<short string>", ...]
}
```

`verdict_reasons` lists every fail and warn signal that fired, plus advisory info. Empty / single-entry "within healthy range" line on a clean PASS.

## Phase 4 (`4_cpu_variance`) — full detail

Produced by `cpu-variance.sh`. Comparable across submissions when grouped by `unit.chip` + `unit.memory_gb` + `unit.perf_cores`.

```json
{
  "verdict": "pass",
  "duration_s": 605,
  "details": {
    "chassis_class": "active-cooled-pro",
    "burst_sec": 5,
    "warmup_sec": 300,
    "iterations": 5,
    "seconds_per_iter": 60,
    "workers": 12,
    "burst_throughput_mb_per_s": 28640.2,
    "warmup_tail_throughput_mb_per_s": 23110.5,
    "throughput_mb_per_s": [23080.3, 23142.1, 23071.9, 23105.4, 23048.7],
    "min_mb_per_s": 23048.7,
    "max_mb_per_s": 23142.1,
    "mean_mb_per_s": 23089.7,
    "stdev_mb_per_s": 36.4,
    "spread_pct": 0.405,
    "max_to_min_ratio": 1.004,
    "early_vs_late_decline_pct": 0.213,
    "burst_to_steady_ratio": 0.806,
    "worker_imbalance_pct_per_iter": [0.4, 0.6, 0.3, 0.5, 0.4],
    "median_worker_imbalance_pct": 0.4,
    "workload": "sha256-parallel (hardware-accelerated on Apple Silicon — see script header CAVEAT)"
  },
  "verdict_reasons": [
    "spread 0.41%, ratio 1.00×, decline 0.21% — within healthy range"
  ]
}
```

## Phase 5 (`5_thermal_load`) — full detail

Produced by `thermal-load.sh`. Includes ambient temp for cross-machine comparison.

```json
{
  "verdict": "pass",
  "duration_s": 600,
  "details": {
    "chassis_class": "active-cooled-pro",
    "sample_interval_s": 5,
    "workers": 12,
    "samples_captured": 120,
    "data_quality": "ok",
    "data_quality_notes": [],
    "powermetrics_rc": 0,
    "ambient_temp_c": { "first_sample": 22.3, "max_during_run": 24.1 },
    "cpu_die_temp_c": { "n": 120, "min": 64.2, "max": 94.8, "mean": 89.3, "first": 64.2, "last": 91.7 },
    "gpu_die_temp_c": { "n": 120, "min": 38.1, "max": 52.4, "mean": 47.8, "first": 38.1, "last": 49.6 },
    "fan_rpm_avg":    { "n": 120, "min": 1840, "max": 5840, "mean": 5510, "first": 1840, "last": 5780 },
    "p_cluster_freq_mhz": { "n": 120, "min": 3540, "max": 4280, "mean": 3892, "first": 4280, "last": 3580 },
    "combined_power_w": { "n": 120, "min": 8.4, "max": 64.2, "mean": 58.7, "first": 8.4, "last": 60.3 },
    "early_cliff_pct": 6.8,
    "frequency_cliff_pct": 8.1,
    "steady_state_vs_peak_pct": 84.3,
    "thresholds_used": { "cpu_temp_warn": 100, "cpu_temp_fail": 105, "...": "..." }
  },
  "verdict_reasons": ["all thresholds passed (active-cooled-pro)"]
}
```

## Privacy / submission-safety

Reports default to submission-safe:
- **Serial number is hashed** (SHA-256) — done by `inventory.sh` (and `battery.sh` for the battery serial). The plaintext serial is **not** stored unless `INCLUDE_PLAINTEXT_SERIAL=1` is set, in which case the agent sets `submission_safe: false`. The hash lets the aggregator detect duplicate submissions of the same unit without revealing identity.
- **`store_location`, `purchase_date`** are `null` by default. Opt in to enable batch-correlation (e.g. "all units bought at HK Apple Causeway Bay in April 2026 with this defect").
- **`_raw_*` fields** in the inventory and battery sub-blocks contain the full `system_profiler` / `ioreg` dumps and may include paired Bluetooth device IDs, Wi-Fi SSIDs, USB device serials, etc. The agent strips these from the canonical submission JSON and keeps them only in the local `Reports/<ts>-raw/*.json` per-phase artifacts. **`submission_safe: true`** asserts they're stripped.
- **`submission_safe: true`** is the agent's assertion that no PII has snuck in. If the user adds free-form notes that might contain identifying info, the agent should set this to `false` and warn.

## Versioning policy

- **Patch bumps (1.0.0 → 1.0.1)** add optional fields. Old aggregators read the new reports fine.
- **Minor bumps (1.0 → 1.1)** can change non-critical structure. Aggregator handles both.
- **Major bumps (1.0 → 2.0)** are breaking. Aggregator must explicitly support each major version.

If a test methodology changes (e.g. variance test gains a new metric, or thresholds shift), bump at least the patch version and document the change in [CHANGELOG.md](../CHANGELOG.md). Methodology changes that affect comparability across submissions should bump the minor or major.
