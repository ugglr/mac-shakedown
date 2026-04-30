# Changelog

All notable changes to this project are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the JSON report schema follows the versioning contract in [`Reports/SCHEMA.md`](Reports/SCHEMA.md) — any change to the test methodology (runbook, thresholds, or scripts) bumps at least the patch version of the schema so submitted reports stay sortable across method revisions.

## [0.1.0] — 2026-04-30

### Added

- Verification machinery (generation-agnostic): runbook, pass/fail criteria parameterized by chassis class, and the five core scripts — `inventory.sh`, `battery.sh`, `cpu-variance.sh`, `thermal-load.sh`, `display-test.sh`.
- Phase 0–9 procedure: pre-flight, hardware identity, battery health, sensor inventory, CPU variance (5 s burst + chassis-class warmup + 5 × 60 s timed iterations, parallel SHA-256), 10-minute sustained thermal load with `powermetrics` sampling, fullscreen display visual inspection, manual physical inspection, Apple Diagnostics, and an optional 30-minute idle-drain test.
- Target presets: `mbp-16-m5-max-64`, `mbp-14-m5-pro-24`, `macbook-air-m5-16`.
- M5 (2026) generation calibration under `examples/m5-2026/` — the documented defect landscape, source list, and the tuned thresholds the M5 presets reference.
- `AGENTS.md` cross-tool agent operating manual, with `CLAUDE.md` as the Claude Code auto-loader pointer; tested invocation paths for Cursor, Cline / Roo Code, Aider, and OpenAI Codex CLI.
- JSON report schema v1.0 (see `Reports/SCHEMA.md`): canonical machine-readable artifact with hashed serial, submission-safety flag, and opt-in fields for future crowd-sourced aggregation.

### Notes

The methodology has not yet been validated against a confirmed-defective unit. Thresholds are derived from public reports and a small number of presumed-good runs, and are expected to tighten as crowd-sourced submissions land. Treat current PASS verdicts as "no obvious defect detected," not "certified good."

[0.1.0]: https://github.com/ugglr/mac-shakedown/releases/tag/v0.1.0
