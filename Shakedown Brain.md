---
created: 2026-04-29
tags: [moc, index]
---

# Shakedown Brain

Obsidian map-of-content for the Shakedown repo. If you opened the folder in Obsidian, this is your entry point. If you're browsing on GitHub, [README.md](README.md) is the better entry point.

Shakedown is a Claude-Code-driven verification harness for new Apple Silicon Macs — a procedure for catching batch-level defects in the return window. (Name borrowed from engineering — a *shakedown run* is the first-run stress test of new machinery before commissioning.)

## Map of Content

### Verification machinery (generation-agnostic)
- [[Verification/Runbook]] — phase-by-phase procedure (Pre-flight → Inventory → Battery → Variance → Thermal → Display → Manual → Diagnostics → Drain → Report)
- [[Verification/Pass-Fail Criteria]] — concrete thresholds, parameterized by chassis class
- [[CLAUDE]] — agent operating manual (auto-loaded by Claude Code)
- Scripts in `Verification/scripts/`:
	- `inventory.sh` — `system_profiler` + `sysctl` → JSON
	- `battery.sh` — `ioreg` battery health → JSON
	- `cpu-variance.sh` — warmup + time-capped parallel SHA-256, throughput stats → JSON
	- `thermal-load.sh` — 10-min sustained load + `powermetrics` → JSON *(needs sudo)*
	- `display-test.sh` — fullscreen color cycle in browser for visual inspection

### Targets
- [[targets/README|Target presets]] — preset SKU configs (chip / RAM / chassis / calibration pointer)
- Current presets: `mbp-16-m5-max-64`, `mbp-14-m5-pro-24`, `macbook-air-m5-16`

### Generation calibrations
- [[examples/m5-max-2026/README|examples/m5-max-2026/]] — M5 generation (2026) defect landscape
	- [[examples/m5-max-2026/M5 Quality Issues|M5 Quality Issues]] — overview
	- Issues:
		- [[examples/m5-max-2026/Issues/Performance Variance|Performance Variance]] ⚠️ *most critical*
		- [[examples/m5-max-2026/Issues/Thermal Throttling|Thermal Throttling]]
		- [[examples/m5-max-2026/Issues/Battery Defects|Battery Defects]]
		- [[examples/m5-max-2026/Issues/Hinge & Palmrest Creak|Hinge & Palmrest Creak]]
		- [[examples/m5-max-2026/Issues/Display|Display]]
		- [[examples/m5-max-2026/Issues/Other Reported Issues|Other Reported Issues]]
		- [[examples/m5-max-2026/Issues/Repairability|Repairability]] *(context, not a defect to test for)*
	- [[examples/m5-max-2026/Sources|Sources]]

### Reports
- [[Reports/SCHEMA|JSON report schema (v1.0)]] — canonical output format, designed for opt-in submission to a future hosted aggregator

### Project meta
- [[README]] — public README with one-liner and quick start
- [[CONTRIBUTING]] — adding target presets and generation calibrations

## Key insight

The defect class that motivated Shakedown: **batch-level performance variance** that doesn't show up in a quick boot test. The 2026 M5 Max line had units showing up to 41.5% multi-core variance between identical runs — invisible until you ran repeated sustained-load benchmarks on a thermally-saturated chassis. This is what `cpu-variance.sh` is designed to catch.

Cosmetic / build issues (hinge creak, dead pixels, speaker crackle) are obvious on first inspection — the agent prompts you for those manually. The unique value of the harness is in the load-and-thermal phases.
