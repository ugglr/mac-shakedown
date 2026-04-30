---
created: 2026-04-30
tags: [verification, criteria]
---

# Pass-Fail Criteria

Concrete thresholds for each check in the [Runbook](Runbook.md). Generation-agnostic — chassis-specific differences are handled via the target's `thermal_chassis_class`.

## Hardware identity

Asserted from the loaded target (no defaults):

| Check | Pass | Fail | Source |
|---|---|---|---|
| `chip_pattern` substring | matches | doesn't | `inventory.json` → `summary.chip` |
| `memory_gb` exact | matches | doesn't | `summary.memory_gb` |
| `model_must_include` substring | matches | doesn't | `summary.model` |
| SSD SMART status | "Verified" | anything else | `storage[].smart` |

A miss on any of the first three is a **stop-the-run** condition. Ask the user before proceeding — they may be verifying the wrong unit.

## Battery

| Check | Pass | Warn | Fail |
|---|---|---|---|
| Cycle count | ≤ 1 | 2–5 | > 5 |
| Condition | "Normal" | — | anything else |
| Max capacity vs. design | ≥ 99% | 95–99% | < 95% |

> 5 cycles on a "new" unit is a strong indicator of a returned/refurb unit relabeled as new — happens occasionally, especially with traveler-bought units. Worth pushing back at the store.

## Sensor & port inventory

Always-present items (any modern Mac with a battery): camera, microphone, speakers, Wi-Fi, Bluetooth, Touch ID.

Form-factor specific (use the unit's own report as truth):
- MacBook Pro 14"/16": expect Thunderbolt ports (2 or 3 depending on SKU), HDMI, SDXC, MagSafe.
- MacBook Air: expect Thunderbolt ports (2), MagSafe. No HDMI/SDXC.
- Mac mini / Studio: expect Thunderbolt + HDMI + Ethernet. No battery, so skip Phase 2.

Pass = everything advertised by Apple for that exact model is reported. Fail = anything missing.

## CPU variance test (the headline check)

Test methodology: 90 s warmup (discarded) → 5 × 60 s timed iterations on a thermally-saturated chassis.

| Check | Pass | Warn | Fail |
|---|---|---|---|
| `spread_pct` `(max-min)/mean × 100` | < 5% | 5–10% | > 10% |
| `max_to_min_ratio` | < 1.2× | 1.2–1.4× | ≥ 1.4× |
| `early_vs_late_decline_pct` (early half mean → late half mean) | < 5% | 5–10% | > 10% |
| Mean throughput vs. calibration baseline | within ±10% | within ±15% | > 15% |

Any FAIL across these strongly suggests a batch-level defect — most commonly hot-spot throttling from uneven thermal paste application. Cite the calibration's Performance Variance note in the report (e.g. [for the M5 generation](../examples/m5-max-2026/Issues/Performance%20Variance.md)) and recommend the user not accept this unit.

Why three metrics? They catch different failure modes:
- `spread_pct` catches noisy, intermittent throttling (some iters fast, some slow, in any order).
- `max_to_min_ratio` catches a single-iteration cliff (one iteration drastically slower than the rest).
- `early_vs_late_decline_pct` catches a *monotonic* decline — one iteration after another dropping — the specific signature of a hot spot crossing its threshold mid-test, which `spread_pct` understates if the slope is steady.

> **Calibration baseline.** Once the [hosted aggregator](../README.md#roadmap) lands, the "mean throughput vs. baseline" check will use crowd-sourced reference distributions. Until then, the variance/decline metrics are the dominant signal.

## Sustained thermal load — by chassis class

Set on the target via `thermal_chassis_class`. Defaults to `active-cooled-pro` if unset.

### `active-cooled-pro` (MacBook Pro 14" / 16")

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 100°C | 100–105°C | > 105°C |
| Steady-state P-core freq vs. peak | ≥ 70% | 60–70% | < 60% |
| Mid-run frequency cliff | none > 20% | one 20–30% | any > 30% |
| Time to first throttle | > 90 s | 30–90 s | < 30 s |
| Fan RPM ramp under load | clearly increasing | flat | doesn't engage |

### `fanless` (MacBook Air)

Air throttles aggressively by design. Looser thresholds:

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 105°C | 105–110°C | > 110°C |
| Steady-state P-core freq vs. peak | ≥ 50% | 40–50% | < 40% |
| Mid-run frequency cliff | none > 40% | one 40–50% | any > 50% |
| Time to first throttle | n/a (always throttles) | — | — |

### `desktop` (Mac mini / Studio / iMac)

Massive thermal headroom — strictest thresholds, throttling is a real defect:

| Check | Pass | Warn | Fail |
|---|---|---|---|
| CPU die temp max | < 90°C | 90–100°C | > 100°C |
| Steady-state P-core freq vs. peak | ≥ 90% | 80–90% | < 80% |
| Mid-run frequency cliff | none > 10% | one 10–20% | any > 20% |
| Fan RPM ramp under load | clearly increasing | flat | doesn't engage |

## Display visual

Manual. Pass = no dead/stuck pixels, no severe backlight bleed, no obvious tint patches.

Note: mini-LED blooming around bright objects on dark backgrounds is **inherent to the panel, not a defect** — do not fail for this. Applies to MBP 14"/16" and Studio Display.

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
| Drain over 30 min sleep | ≤ 5% | 5–10% | > 10% |
