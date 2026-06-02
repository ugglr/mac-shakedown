---
created: 2026-04-30
tags: [verification, criteria]
---

# Pass-Fail Criteria

Concrete thresholds for each check in the [Runbook](Runbook.md). Generation-agnostic. Chassis-specific differences are handled via the target's `thermal_chassis_class`.

## Hardware identity

Asserted from the loaded target (no defaults):

| Check | Pass | Fail | Source |
|---|---|---|---|
| `chip_pattern` substring | matches | doesn't | `inventory.json` → `summary.chip` |
| `memory_gb` exact | matches | doesn't | `summary.memory_gb` |
| `model_must_include` substring | matches | doesn't | `summary.model` |
| SSD SMART status | "Verified" | anything else | `storage[].smart` |

A miss on any of the first three is a **stop-the-run** condition. Ask the user before proceeding. They may be verifying the wrong unit.

## Battery

| Check | Pass | Warn | Fail |
|---|---|---|---|
| Cycle count | ≤ 1 | 2–5 | > 5 |
| Condition | "Normal" | n/a | anything else |
| Max capacity vs. design | ≥ 99% | 95–99% | < 95% |

> 5 cycles on a "new" unit is a strong indicator of a returned/refurb unit relabeled as new. Happens occasionally, especially with traveler-bought units. Worth pushing back at the store.

## Sensor & port inventory

Always-present items (any modern Mac with a battery): camera, microphone, speakers, Wi-Fi, Bluetooth, Touch ID.

Form-factor specific (use the unit's own report as truth):
- MacBook Pro 14"/16": expect Thunderbolt ports (2 or 3 depending on SKU), HDMI, SDXC, MagSafe.
- MacBook Air: expect Thunderbolt ports (2), MagSafe. No HDMI/SDXC.
- Mac mini / Studio: expect Thunderbolt + HDMI + Ethernet. No battery, so skip Phase 2.

Pass = everything advertised by Apple for that exact model is reported. Fail = anything missing.

## CPU variance test (the headline check)

Test methodology: cold-start burst (5 s), chassis-class-aware warmup (discarded), 5 × 60 s timed iterations on a thermally-saturated chassis.

**Warmup duration by chassis class** (configurable via `WARMUP_SEC` env var):

| Chassis class | Warmup default | Rationale |
|---|---|---|
| `fanless` | 60 s | Apple Silicon Air saturates fast |
| `active-cooled-pro` (and `-14` / `-16`) | 300 s | 16" MBP saturation is 5–8 min; 90 s leaves iter 1 still on the heating curve. All three Pro sub-classes share this warmup; they differ only in the thermal thresholds below. |
| `desktop` | 180 s | Some headroom, but bigger thermal mass |
| `intel-laptop` | 180 s | Intel laptops saturate quickly under load |
| `intel-desktop` | 180 s | Similar |

**Verdict thresholds** (chassis-agnostic, variance is universal):

| Check | Pass | Warn | Fail |
|---|---|---|---|
| `spread_pct` `(max-min)/mean × 100` | < 5% | 5–10% | > 10% |
| `max_to_min_ratio` | < 1.2× | 1.2–1.4× | ≥ 1.4× |
| `early_vs_late_decline_pct` (early half mean → late half mean) | < 5% | 5–10% | > 10% |
| Mean throughput vs. calibration baseline | within ±10% | within ±15% | > 15% |
| `burst_to_steady_ratio` (mean / burst throughput) | informational, see below |||
| `max_worker_imbalance_pct` (worst within-iter spread across workers) | < 10% | 10–20% | > 20% |
| Dead worker (any iter throughput == 0) | n/a | n/a | any |

**Compound-warn escalation:** the script automatically escalates **2 or more independent warn signals** to `fail`. A unit that lands in WARN on spread *and* decline *and* ratio at the same time isn't borderline. It's failing across multiple methodologies. The single-warn-rerun discipline (Runbook Phase 4) only applies to a single warn signal.

Why three metrics? They catch different failure modes:
- `spread_pct` catches noisy, intermittent throttling (some iters fast, some slow, in any order).
- `max_to_min_ratio` catches a single-iteration cliff (one iteration drastically slower than the rest).
- `early_vs_late_decline_pct` catches a *monotonic* decline (one iteration after another dropping), the specific signature of a hot spot crossing its threshold mid-test, which `spread_pct` understates if the slope is steady.

> **`burst_to_steady_ratio` is advisory.** A ratio close to 1.0 (steady ≈ burst) on an `active-cooled-pro` chassis can indicate "always-throttled" units that look consistent in iterations because they were already throttled at the warmup tail. But on `fanless` and `desktop` classes a high ratio is normal (Air has no thermal headroom to give up; desktop has so much that steady stays close to burst). The script records the value but does *not* drive verdict from it. Compare against the calibration baseline.


> **Workload caveat.** Phase 4 uses parallel SHA-256, which is hardware-accelerated on Apple Silicon (and Coffee Lake+ Intel). The test stresses the SHA engines, multiprocessing scheduling, and chassis thermal mass, but does **not** probe integer pipelines, memory bandwidth, or large-cache thermal behavior as deeply as Cinebench / Geekbench would. Public reports of the M5 Max defect originate from those benchmarks; this test catches *correlated* signals (timing variance + thermal saturation behavior) but isn't 1:1 with the reported workloads. **Phase 4b** (`./run --noaccel`) closes that gap: it reruns the same variance methodology with BLAKE2b, which has no CPU crypto instruction and so exercises the integer pipelines and memory the way Cinebench / Geekbench do. Same thresholds (variance is a within-unit measure), different workload. The bands are reused from Phase 4 as-is for now; if BLAKE2b turns out to have a different healthy-unit noise floor than SHA-256, that gets its own calibration once Phase 4b corpus data lands in v0.3.

> **Calibration baseline.** Once the [hosted aggregator](../README.md#roadmap) lands, the "mean throughput vs. baseline" check uses crowd-sourced reference distributions per (chip, memory, perf_cores). Until then, the variance/decline metrics are the dominant signal. They don't need an external reference because they measure *consistency within a single unit*.

## Sustained thermal load: by chassis class

Set on the target via `thermal_chassis_class`. Defaults to `active-cooled-pro` if unset. The script automatically escalates **3 or more warn signals** to `fail` (compound-warn escalation).

The thermal test reports both an **early-window cliff** (first 30 s, the textbook bad-batch signature, "cliffs to base clock within 30 s") and a **mid-run cliff** (after the 90 s load-startup transient). Both are evaluated against chassis-class thresholds; either crossing fail = unit fails.

### `active-cooled-pro-16` (Apple Silicon MacBook Pro 16")

The bare `active-cooled-pro` class is an alias for these thresholds, so existing presets and prior submissions stay comparable. Auto-detect (no `--target`) also lands here, because `system_profiler` does not reliably expose screen size on Apple Silicon. On a 14", pass `--target mbp-14-...` (or `CHASSIS_CLASS=active-cooled-pro-14`) so its design throttling isn't read as a defect.

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 100°C | 100–105°C | > 105°C |
| Steady-state P-core freq vs. peak | ≥ 70% | 60–70% | < 60% |
| **Early-window** (first 30 s, after a 10 s startup skip) frequency cliff | < 25% | 25–40% | > 40% |
| Mid-run frequency cliff (after 90 s) | < 20% | 20–30% | > 30% |
| Fan RPM ramp under load | ≥ 200 RPM | 1–199 RPM | no fan data captured (info-only) |

### `active-cooled-pro-14` (Apple Silicon MacBook Pro 14")

The 14" has a smaller fan and less thermal mass, and the 14" M5 Max throttles by design under sustained Pro-class load (see the [Thermal Throttling note](../examples/m5-2026/Issues/Thermal%20Throttling.md)). Looser steady-state and cliff bands keep a healthy-but-throttling 14" out of the warn band. Selected only via a `--target mbp-14-...` preset, never by auto-detect.

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 100°C | 100–105°C | > 105°C |
| Steady-state P-core freq vs. peak | ≥ 60% | 50–60% | < 50% |
| Early-window cliff | < 35% | 35–50% | > 50% |
| Mid-run cliff | < 30% | 30–40% | > 40% |
| Fan RPM ramp under load | ≥ 200 RPM | 1–199 RPM | no fan data captured (info-only) |

### `fanless` (Apple Silicon MacBook Air)

Air throttles aggressively by design. Looser thresholds:

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 105°C | 105–110°C | > 110°C |
| Steady-state P-core freq vs. peak | ≥ 50% | 40–50% | < 40% |
| Early-window cliff | < 50% | 50–70% | > 70% |
| Mid-run cliff | < 40% | 40–50% | > 50% |
| Fan ramp | n/a (no fan) | n/a | n/a |

### `desktop` (Apple Silicon Mac mini / Studio / iMac)

Massive thermal headroom, strictest thresholds, throttling is a real defect:

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 90°C | 90–100°C | > 100°C |
| Steady-state P-core freq vs. peak | ≥ 90% | 80–90% | < 80% |
| Early-window cliff | < 15% | 15–25% | > 25% |
| Mid-run cliff | < 10% | 10–20% | > 20% |
| Fan RPM ramp under load | ≥ 200 RPM increase | n/a | < 200 RPM, fan likely not engaging (FAIL on desktop) |

### `intel-laptop` (Intel MacBook Pro / Air)

Intel laptops throttle hard by design, looser steady-state and cliff thresholds. Tjmax is typically 100°C and Intel throttles aggressively well before that.

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 98°C | 98–105°C | > 105°C |
| Steady-state CPU freq vs. peak | ≥ 50% | 35–50% | < 35% |
| Early-window cliff | < 40% | 40–55% | > 55% |
| Mid-run cliff | < 35% | 35–50% | > 50% |
| Fan RPM ramp | clearly increasing | flat | doesn't engage |

### `intel-desktop` (Intel iMac / Mac mini)

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 90°C | 90–100°C | > 100°C |
| Steady-state CPU freq vs. peak | ≥ 75% | 60–75% | < 60% |
| Early-window cliff | < 25% | 25–40% | > 40% |
| Mid-run cliff | < 20% | 20–30% | > 30% |
| Fan RPM ramp | clearly increasing | flat | doesn't engage |

### Data quality (all classes)

| Check | Pass | Warn | Fail |
|---|---|---|---|
| `data_quality` | "ok" | "few_samples" | "no_samples" |

`no_samples` is a **fatal verdict**. No metrics can be trusted, so the entire phase fails regardless of other readings. This catches sudo failures, powermetrics format changes, and similar.

## Calibration benchmarks (race, SSD, memory bandwidth, GPU)

Phases 10 (race), 11 (SSD), 12 (memory bandwidth), and 13 (GPU) are calibration inputs in v0.2. They emit `verdict: "info"` and don't pass/fail on their own: there's no chassis-family baseline corpus yet, and inventing absolute numbers would just produce false verdicts. They're recorded so the future per-SKU baselines can be built. Chassis-family pass/fail bands land in v0.3 once the submission corpus is non-empty.

Two deliberately conservative exceptions:

| Phase | Trigger | Behavior |
|---|---|---|
| 11 SSD | `read` or `write` < 500 MB/s with the page cache dropped | `warn` (advisory, never fail). Every NVMe-equipped Mac since ~2016 clears > 1000 MB/s; below 500 points at the 256 GB single-NAND-die regression, a failing drive, or pre-NVMe storage. |
| 4b non-accelerated variance | same variance thresholds as Phase 4 | real `pass` / `warn` / `fail` when run (opt-in via `--noaccel`). Variance is a within-unit measure, so the thresholds transfer across workloads. |

Memory bandwidth (Phase 12) and GPU variance (Phase 13) stay `info` only: per-chip bandwidth and GFLOP/s vary too widely (DDR4 Intel vs LPDDR5 Apple Silicon, integrated vs discrete GPU) for a single floor to mean anything. Their spread / consistency metrics are recorded for the aggregator.

## Display visual

Manual. Pass = no dead/stuck pixels, no severe backlight bleed, no obvious tint patches.

Note: mini-LED blooming around bright objects on dark backgrounds is **inherent to the panel, not a defect**. Do not fail for this. Applies to MBP 14"/16" Apple Silicon and the Studio Display.

## Build quality (manual)

| Check | Pass | Fail |
|---|---|---|
| Hinge creak (open/close, press, twist) | silent / solid | audible creak |
| Palmrest flex | solid | bends or clicks |
| Trackpad force-click on all corners | uniform | dead corner |
| Every keyboard key | all responsive | sticky / double / dead |
| Touch ID enrollment | succeeds | fails |
| Speaker at 70% with bass | clean | crackle / buzz / asymmetric |
| Mic capture | clear | distorted / silent |
| Camera | clean | banding / dead pixels |
| Each USB-C port (charge + data) | both work | one fails |
| MagSafe (where applicable) | engages and disengages cleanly | doesn't hold / weak magnet |

## Apple Diagnostics

Pass = "No issues found" or all-clear. Fail = any reference code (cross-reference [Apple's diagnostic code list](https://support.apple.com/en-us/102713) in the report).

## Optional idle drain

Skip on desktops (no battery).

| Check | Pass | Warn | Fail |
|---|---|---|---|
| Battery remaining after 30 min sleep | ≥ 95% | 90–95% | < 90% |
| Equivalent drain | ≤ 5% | 5–10% | > 10% |

Both rows describe the same threshold from different angles. `pmset -g batt` reports remaining %, while the calibration notes phrase observations as drain %. They're equivalent.
