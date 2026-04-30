# Changelog

All notable changes to this project are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the JSON report schema follows the versioning contract in [`Reports/SCHEMA.md`](Reports/SCHEMA.md) — any change to the test methodology (runbook, thresholds, or scripts) bumps at least the patch version of the schema so submitted reports stay sortable across method revisions.

## [Unreleased]

### Added — methodology hardening

- **Phase 4 cold burst measurement** — first 5 s of parallel SHA-256 captured before warmup heats the chassis. Burst figure recorded as `burst_throughput_mb_per_s` for diagnostic comparison against the steady-state mean (advisory; doesn't drive verdict without a calibration baseline).
- **Phase 4 chassis-class-aware warmup defaults** — `active-cooled-pro` now defaults to **300 s** (was 90 s; a 16" MBP needs 5–8 min to reach thermal saturation). `fanless` defaults to 60 s, `desktop` / `intel-laptop` / `intel-desktop` default to 180 s. Total Phase 4 runtime: ~10 min on Pro, ~6 min on Air.
- **`max_to_min_ratio` warn band 1.2–1.4×** — was previously fail-only at ≥ 1.4×; the warn band catches near-miss units.
- **Phase 4 dead-worker safeguard** — any iteration with zero throughput now forces fail (was previously masked by `min(throughputs) > 0 else 1.0` fallback that produced ratio = 1.0 → silent PASS).
- **Phase 4 worker-imbalance reporting** — within-iter `(max_worker - min_worker) / max_worker × 100` recorded per iteration, so a defective single core is at least visible in the JSON even if the macOS scheduler routes around it.
- **Phase 5 early-window cliff metric** — first 30 s frequency cliff now evaluated separately from the post-warmup mid-run cliff. The textbook bad-batch signature ("cliffs to base clock within 30 s under load") was previously thrown away by the 90 s warmup-skip; it's now `early_cliff_pct` with chassis-class thresholds.
- **Phase 5 ambient-temp capture** — `powermetrics` Ambient/Battery temp readings recorded as `ambient_temp_c.first_sample` and `.max_during_run`, useful for cross-machine comparison (a Mac tested in a 32 °C store hits limits faster than one in a 21 °C lab).
- **Phase 5 chassis-class-aware verdicts** — script previously hardcoded `active-cooled-pro` thresholds, which would false-fail an Air or false-pass a desktop. Now reads `CHASSIS_CLASS` env var (default `active-cooled-pro`) and applies the correct threshold table.
- **Phase 5 multi-fan regex** — handles `Fans:` headers + per-fan lines on 16" MBP and Mac Studio (previously matched only `Fan:` and `Fan N:`, leaving fan_avgs empty on multi-fan chassis).
- **Phase 5 data-quality safety net** — `data_quality: "no_samples"` automatically forces fail. Previously the verdict logic could short-circuit on empty lists and emit a misleading PASS with no reasons when sudo failed or powermetrics output format changed.
- **Compound-warn escalation** — Phase 4 escalates 2+ warn signals to fail; Phase 5 escalates 3+. Multiple simultaneous near-threshold readings shouldn't aggregate to a single warn.
- **Process-group kill in Phase 5** — `thermal-load.sh` now backgrounds the load in its own process group and `kill -- -$LOAD_PGID`s on EXIT/INT/TERM. Previously `kill $LOAD_PID` only signalled the parent Python and orphaned the multiprocessing pool.
- **Hashed serial numbers actually happen** — `inventory.sh` and `battery.sh` now hash serial numbers with SHA-256 by default and emit `serial_hash` (the README claimed this; the implementation now matches the claim). Plaintext serial is opt-in via `INCLUDE_PLAINTEXT_SERIAL=1`.
- **Privacy-aware inventory output** — full `system_profiler` and `ioreg` dumps moved into `_raw_*` fields with comments explaining they may contain paired Bluetooth IDs, Wi-Fi SSIDs, USB device serials, etc. Agent strips these from canonical submission JSON.

### Added — Intel + older Apple Silicon support

- **`intel-laptop` and `intel-desktop` chassis classes** — looser thermal thresholds reflecting Intel's aggressive throttling (steady-state ≥ 50% of peak rather than ≥ 70%).
- **Intel powermetrics format** — `thermal-load.sh` now also parses `CPU N frequency:`, `Package Power:`, `IA Cores Power:`, `GT Cores Power:` so frequency and power summaries populate on Intel.
- **`mbp-16-intel-2019.json`** target preset as a worked example.
- **`inventory.sh` Intel chip detection** — falls back to `cpu_type` when `chip_type` is absent (Apple Silicon vs. Intel system_profiler keys differ); records `is_apple_silicon` flag for downstream reasoning.
- Generation coverage table in `targets/README.md`: M5 (primary), M1–M4 (scripts work, no per-generation calibration yet), Intel 2018+ (works with new chassis classes), pre-2018 (untested).

### Added — OSS hygiene

- `CHANGELOG.md` (this file).
- `SECURITY.md` — surface-area summary, the only `sudo` use (`powermetrics`), private security advisory pointer.
- `.github/ISSUE_TEMPLATE/{defect-report,bug-report,config}.yml` — form-style templates with PII-review checklist tied to `submission_safe`/`store_location`/etc.
- `.github/pull_request_template.md` — type-of-change checklist + validation requirements (run affected scripts, paste JSON, note chip/RAM).
- `.github/workflows/lint.yml` — shellcheck on every script, `python3 -m json.tool` on every target preset, `ast.parse` on every Python heredoc, markdown-link existence check.
- `examples/sample-report-illustrative/` — hand-crafted example PASS run on a 16" M5 Max 64 GB so visitors can see what the harness produces without running it themselves.
- README "Status (v0.1)" callout disclosing the methodology has not yet been validated against a confirmed-defective unit.
- README "Supported agents" table with verification status per agent (Claude Code ✅, others 🟡 unverified).
- README Quick start broken into numbered steps so the `xcode-select --install` 5–10 min wait is no longer hidden in a comment.

### Changed

- `examples/m5-max-2026/` → `examples/m5-2026/` (calibration covers M5 / M5 Pro / M5 Max — the Air target preset reuses the same calibration directory).
- `Verification/Pass-Fail Criteria.md` rewritten with chassis-class threshold tables, compound-warn escalation, the `burst_to_steady_ratio` advisory note, and the SHA-256 workload caveat.
- README total runtime claim updated: ~45 min on MBP, ~25 min on Air, ~35 min on desktop / Intel (was a flat ~40 min).
- `AGENTS.md` operating principles expanded to cover `CHASSIS_CLASS` pass-through (with `sudo -E`), rerun-on-warn discipline, and trust-the-data_quality-field guidance.
- Drain framing reconciled across Runbook + Pass-Fail Criteria — both `% remaining` and `% drain` documented for the 30-min idle test.

### Known limitations (calibration baseline pending)

- The methodology has not yet been validated against a confirmed-defective unit. Thresholds are derived from public reports and a small number of presumed-good runs.
- Phase 4 uses SHA-256 which is hardware-accelerated on Apple Silicon and Coffee Lake+ Intel — it stresses the SHA engines + scheduling + thermal mass but not the integer pipelines or memory bandwidth that Cinebench / Geekbench probe more thoroughly. The variance methodology transfers cleanly to any sustained workload; the SHA choice is for zero-install portability. A non-accelerated workload pass is on the roadmap.
- GPU not yet covered. Memory bandwidth not yet covered. NVMe SSD performance not yet covered (only SMART status).
- 14" vs 16" MBP currently share the `active-cooled-pro` threshold table — the calibration's [Thermal Throttling note](examples/m5-2026/Issues/Thermal%20Throttling.md) describes 14" M5 Max throttling as design behavior, so a working 14" may land in the warn band of the current thresholds. A separate 14" sub-class is on the roadmap.

## [0.1.0] — 2026-04-30

### Added

- Initial release.
- Verification machinery (generation-agnostic): runbook, pass/fail criteria parameterized by chassis class, and the five core scripts — `inventory.sh`, `battery.sh`, `cpu-variance.sh`, `thermal-load.sh`, `display-test.sh`.
- Phase 0–9 procedure: pre-flight, hardware identity, battery health, sensor inventory, CPU variance (90 s warmup + 5 × 60 s timed iterations, parallel SHA-256), 10-minute sustained thermal load with `powermetrics` sampling, fullscreen display visual inspection, manual physical inspection, Apple Diagnostics, and an optional 30-minute idle-drain test.
- Target presets: `mbp-16-m5-max-64`, `mbp-14-m5-pro-24`, `macbook-air-m5-16`.
- M5 (2026) generation calibration under `examples/m5-max-2026/` (renamed in [Unreleased]).
- `AGENTS.md` cross-tool agent operating manual, with `CLAUDE.md` as the Claude Code auto-loader pointer.
- JSON report schema v1.0 with hashed-serial design, submission-safety flag, and opt-in fields for future crowd-sourced aggregation.

[Unreleased]: https://github.com/ugglr/mac-shakedown/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ugglr/mac-shakedown/releases/tag/v0.1.0
