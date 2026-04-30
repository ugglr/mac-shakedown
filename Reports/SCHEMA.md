# Report Schema

Every QA run produces two artifacts in `Reports/`:

- **`<ISO-timestamp>.json`** — canonical machine-readable report. Stable schema, versioned. *This is what gets submitted to the future aggregator.*
- **`<ISO-timestamp>.md`** — human-readable render of the JSON.

## JSON schema (v1.0)

```json
{
  "schema_version": "1.0",
  "shakedown_version": "0.1.0",
  "timestamp": "2026-04-30T14:30:00Z",

  "target": {
    "preset": "mbp-16-m5-max-64",
    "name": "MacBook Pro 16-inch — M5 Max — 64 GB",
    "chip_pattern": "M5 Max",
    "memory_gb": 64,
    "model_must_include": "16",
    "calibration_dir": "examples/m5-max-2026",
    "thermal_chassis_class": "active-cooled-pro"
  },

  "unit": {
    "model": "MacBook Pro",
    "model_identifier": "Mac17,1",
    "chip": "Apple M5 Max",
    "perf_cores": 12,
    "efficiency_cores": 4,
    "memory_gb": 64,
    "storage_gb": 1024,
    "macos_version": "macOS 16.3 (Tahoe)",
    "serial_hash": "sha256:7c3f…"
  },

  "phases": {
    "0_preflight":      { "verdict": "pass", "duration_s": 12 },
    "1_inventory":      { "verdict": "pass", "duration_s": 1, "details": {} },
    "2_battery":        { "verdict": "pass", "details": { "cycle_count": 0, "max_capacity_pct": 100 } },
    "3_sensors":        { "verdict": "pass", "details": { "missing": [] } },
    "4_cpu_variance":   {
      "verdict": "pass",
      "duration_s": 390,
      "details": {
        "warmup_sec": 90,
        "iterations": 5,
        "seconds_per_iter": 60,
        "throughput_mb_per_s": [12450, 12480, 12410, 12440, 12420],
        "spread_pct": 0.56,
        "max_to_min_ratio": 1.006,
        "early_vs_late_decline_pct": 0.32
      }
    },
    "5_thermal_load":   {
      "verdict": "pass",
      "duration_s": 600,
      "details": { "cpu_die_temp_c_max": 92.1, "frequency_cliff_pct": 4.2, "steady_state_vs_peak_pct": 88.4 }
    },
    "6_display":        { "verdict": "pass", "details": { "manual_responses": { "white": "ok", "red": "ok", "…": "…" } } },
    "7_physical":       { "verdict": "pass", "details": { "manual_responses": { "hinge_creak": false, "every_key": true, "…": "…" } } },
    "8_apple_diagnostics": { "verdict": "pass", "details": { "code": "no_issues_found" } },
    "9_idle_drain":     { "verdict": "skipped", "details": { "reason": "user opted out" } }
  },

  "result": "PASS",
  "result_reason": "all phases pass",

  "submission_safe": true,
  "store_location": null,
  "purchase_date": null
}
```

## Privacy / submission-safety

Reports default to submission-safe:
- **Serial number is hashed** (SHA-256). The original serial is not stored. Hash lets the aggregator detect duplicate submissions of the same unit without revealing identity.
- **`store_location`, `purchase_date`** are `null` by default. The user can opt in if they want batch-correlation (e.g. "all units bought at HK Apple Causeway Bay in April 2026 with this defect").
- **`submission_safe: true`** is the agent's assertion that no PII has snuck in. If the user adds free-form notes containing identifying info, the agent should set this to `false`.

## Versioning policy

- **Patch bumps (1.0 → 1.0.1)** add optional fields. Old aggregators read the new reports fine.
- **Minor bumps (1.0 → 1.1)** can change non-critical structure. Aggregator should handle both.
- **Major bumps (1.0 → 2.0)** are breaking. The aggregator must explicitly support each major version.

If a test methodology changes (e.g. variance test gains a new metric, or thresholds shift), bump at least the patch version and document in this file.
