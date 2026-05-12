# Contributing to Shakedown

Thanks for the interest. Shakedown grows in two directions:

1. **Verification machinery** at repo root, generation-agnostic. Improvements here help everyone.
2. **Generation calibrations** in `examples/`, with Mac-generation-specific notes and tuned thresholds. New generations (M6, M7…) and their batch issues live here.

## Adding a target preset

A target preset lets users run `./run --target <name>` to assert the unit matches a specific SKU. They live in `targets/*.json`.

**Schema** (minimal; the unit's own `system_profiler` output fills in everything else):

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

| Field | Purpose |
|---|---|
| `name` | Human-readable label shown in reports |
| `chip_pattern` | Substring asserted against `system_profiler`'s `chip_type` |
| `memory_gb` | Asserted against `sysctl hw.memsize` |
| `model_must_include` | Substring asserted against `machine_model` (catches chassis size) |
| `calibration_dir` | Path to the `examples/<generation>/` notes for failure-analysis cross-reference |
| `thermal_chassis_class` | One of `fanless`, `active-cooled-pro`, `desktop`, `intel-laptop`, `intel-desktop`. Sets thermal thresholds and Phase 4 warmup duration. See [`targets/README.md`](targets/README.md) for the per-class definition. |

Open a PR adding the JSON. Match an existing one for style.

## Adding a generation calibration

When a new generation lands (or a new batch defect emerges in an existing one), add a folder under `examples/` with the same shape as `examples/m5-2026/`:

```
examples/<generation>-<year>/
├── README.md                # short, what makes this generation special
├── <Generation> Quality Issues.md   # overview / map of content
├── Issues/                  # one file per known issue
│   ├── Performance Variance.md      # if applicable
│   ├── Thermal Throttling.md
│   └── …
└── Sources.md               # all references
```

The verification scripts and runbook **don't need to change**. They're calibration-aware via the loaded target. Only update root files if you're improving the test methodology itself.

## Improving a script

The 5 scripts in `Verification/scripts/` are deliberately self-contained: bash plus Python heredocs, no external dependencies beyond what ships with macOS. Keep it that way. If you need to add a third-party benchmark (Geekbench, sysbench), make it optional with a fallback to the built-in equivalent.

### Validating changes to a script

Before opening a PR that touches `Verification/scripts/*.sh` or threshold values:

1. **Run the affected script(s)** on your own Mac. Paste the JSON output into the PR body.
2. **Note your chip / RAM / macOS version.** That's the validation context.
3. **Run the lint workflow locally** if you can: `shellcheck -x -e SC1091 Verification/scripts/*.sh`. CI runs the same plus heredoc syntax checks and JSON validation.
4. For methodology changes (new metric, threshold shift), include the rationale in the PR description and a brief note about the comparability impact.

We'll need at least one independent confirmation on different hardware before merging methodology changes. Cross-platform claims (Intel + Apple Silicon) need at least one run of each.

## Test methodology changes

Changes to the runbook, pass/fail thresholds, or the test scripts themselves should be discussed in an issue first. These directly impact submitted reports; changing the variance threshold across a release means baselines from previous reports stop being comparable.

When the methodology changes:
- Bump the schema version in [`Reports/SCHEMA.md`](Reports/SCHEMA.md) (patch for additive, minor/major for breaking).
- Add an entry to [`CHANGELOG.md`](CHANGELOG.md) under the Unreleased section calling out the comparability impact.
- If the change affects how reports compare across submissions (e.g. new metric, threshold tightening), call it out explicitly so the future aggregator can bucket old vs. new submissions.

## Submitting a calibration report

Until a hosted aggregator exists, the calibration corpus grows via PRs to `Reports/submissions/`. The orchestrator at `Verification/scripts/run-shakedown.sh` produces a sanitized submission JSON in the predictable filename convention (`{YYYY-MM-DD}-{preset}-{hash4}.json`); add that file in a PR.

What to expect:

1. **CI runs a submission audit** on any PR touching `Reports/submissions/**`. It fails the PR if it sees `_raw_*` fields, a plaintext serial, an off-pattern filename, `submission_safe != true`, or missing SCHEMA-required fields.
2. **Reviewer checks for PII** beyond what CI catches (free-form notes, store location, etc. The orchestrator never writes these unless you pass `--notes`).
3. **Merge.** Your report lives in-repo, dated and attributable to your PR.

Known-good (PASS) submissions are currently the most valuable: the v0.1 thresholds were derived from public reports rather than measured baselines, and a few clean runs from trusted submitters let us tighten "presumed-good" into "calibrated."

The JSON format is the API contract. Keep it stable, version it (`Reports/SCHEMA.md`), and don't break old reports.
