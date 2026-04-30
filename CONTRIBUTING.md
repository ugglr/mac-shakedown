# Contributing to Shakedown

Thanks for the interest. Shakedown grows in two directions:

1. **Verification machinery** at repo root — generation-agnostic. Improvements here help everyone.
2. **Generation calibrations** in `examples/` — Mac-generation-specific notes and tuned thresholds. New generations (M6, M7…) and their batch issues live here.

## Adding a target preset

A target preset lets users run `claude "run QA --target <name>"` instead of typing chip / RAM / chassis each time. They live in `targets/*.json`.

**Schema** (minimal — agent fills in from the Mac's own report for everything else):

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

| Field | Purpose |
|---|---|
| `name` | Human-readable label shown in reports |
| `chip_pattern` | Substring asserted against `system_profiler`'s `chip_type` |
| `memory_gb` | Asserted against `sysctl hw.memsize` |
| `model_must_include` | Substring asserted against `machine_model` (catches chassis size) |
| `calibration_dir` | Path to the `examples/<generation>/` notes the agent should reference |
| `thermal_chassis_class` | One of `fanless`, `active-cooled-pro`, `desktop` — sets thermal thresholds |

Open a PR adding the JSON. Match an existing one for style.

## Adding a generation calibration

When a new generation lands (or a new batch defect emerges in an existing one), add a folder under `examples/` with the same shape as `examples/m5-2026/`:

```
examples/<generation>-<year>/
├── README.md                # short — what makes this generation special
├── <Generation> Quality Issues.md   # overview / map of content
├── Issues/                  # one file per known issue
│   ├── Performance Variance.md      # if applicable
│   ├── Thermal Throttling.md
│   └── …
└── Sources.md               # all references
```

The verification scripts and runbook **don't need to change** — they're calibration-aware via the loaded target. Only update root files if you're improving the test methodology itself.

## Improving a script

The 5 scripts in `Verification/scripts/` are deliberately self-contained — bash + Python heredocs, no external dependencies beyond what ships with macOS. Keep it that way. If you need to add a third-party benchmark (Geekbench, sysbench), make it optional with a fallback to the built-in equivalent.

## Test methodology changes

Changes to the runbook, pass/fail thresholds, or the test scripts themselves should be discussed in an issue first. These directly impact submitted reports — changing the variance threshold across a release means baselines from previous reports stop being comparable.

When the methodology changes, bump the schema version in `Reports/SCHEMA.md` so submitted reports are sortable across method versions.

## Reports submission (future)

A planned hosted aggregator will accept opt-in submissions of `Reports/<ts>.json` to build crowd-sourced baselines per generation. Until that lands, the JSON format is the API contract — keep it stable, version it, and don't break old reports.
