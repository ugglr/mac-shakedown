---
created: 2026-06-02
tags: [verification, methodology, production-qa]
---

# Production QA: where Shakedown is, and what factory-grade needs

Picture a new MacBook Pro coming off the line. Before it ships it should pass a screen good enough to catch the defect class Apple's own QA has been missing on the M5: batch performance variance (a unit that benchmarks fine once, then craters on a repeat run under heat). This doc is the honest engineering gap analysis between what Shakedown is today and what a production-QA station actually requires, plus the architecture to close the distance.

## What a production-QA screen requires

Real silicon and laptop production test is not "run a benchmark and eyeball it." It is:

1. **Calibrated limits, not advisory thresholds.** Pass/fail bands come from characterization of known-good parts, not from public reports. Every limit is defensible against a measured distribution.
2. **A golden reference and binning.** A characterized golden unit (or a population of them) defines the control limits; every unit-under-test is binned against them. Stations are periodically correlated back to the golden so they agree.
3. **Measurement System Analysis (Gage R&R).** Before you trust a pass/fail, you characterize the *measurement system itself*: its repeatability (same unit, same station, repeated) and reproducibility (across stations/conditions). The gage error must be small relative to the tolerance band, or your pass/fail is noise.
4. **Controlled, recorded, gated preconditions.** Ambient temperature, AC power, a quiet system, a defined thermal soak. These are fixtured and held constant, and a run that violates them is rejected, not scored.
5. **Defined defect coverage with a quantified escape rate.** You know which failure modes the screen catches, and the probability a bad unit slips through (the escape rate), backed by seeded-defect or returns data.
6. **Traceability and SPC.** Serial, station, timestamp, and the full measurement record flow into a database. Control charts, Cpk, and yield trends run continuously; drift triggers action.
7. **Takt-appropriate test time.** Functional test is seconds. A *stress screen / burn-in* station is minutes to hours, and that is the right class for a variance defect that only shows under sustained load.

## Where Shakedown is today

| Requirement | Status | The gap |
|---|---|---|
| Measurement | Strong | Own workloads (parallel SHA-256, BLAKE2b, STREAM triad, Metal FMA), within-unit variance/decline, sustained thermal stress. Good signal generation. |
| Calibrated limits | Weak | v0.2 thresholds are advisory, derived from public reports, never validated against a confirmed-defective unit. The baseline mechanism (below) now exists, but the limit *data* needs golden samples. |
| Golden reference + binning | Partial | `compare-reports.sh` diffs a unit against one known-good sibling; `make-baseline.sh` + `baselines/` now turn a population of known-good units into limits. Needs the population. |
| MSA / Gage R&R | Partial | `repeatability.sh` characterizes run-to-run gage error against the tolerance (the repeatability half of Gage R&R). Still needs the characterization run on a golden unit, and reproducibility across stations and days. |
| Controlled conditions | Partial | `--strict` now hard-gates the preconditions we can see before the load (on AC, quiet system) and aborts a run that violates them, so every scored run was taken under comparable conditions. Still no fixturing, and ambient is whatever the room is (only observable post-hoc). |
| Defect coverage / escape rate | Partial | Catches gross multi-core variance, monotonic decline, dead workers, thermal cliffs. Known holes (from the detection audit): a single slow core averaged across N workers, intermittent defects outside the test window, sub-sample-interval transients, memory/GPU-only faults. Escape rate is unquantified. |
| Traceability / SPC | Partial | Each run emits a SCHEMA-versioned JSON with a hashed serial. The PR-submission flow is the aggregator. No control charts, Cpk, or trend. |
| Takt time | OK as burn-in | The ~45-minute `--store` profile is a stress-screen / burn-in station, not a functional-test station. Appropriate for this defect class. |

## The architecture to close it

Built in dependency order, because each leg needs the one before it.

1. **Calibrated baselines (this wave).** `baselines/<preset>.json` holds, per metric, a golden value and a control limit. `make-baseline.sh` computes them from N known-good reports (3-sigma limits once there are enough samples, a tolerance band below that). `./run` loads the baseline for the target SKU when present and bins each metric against it, turning the verdict from "advisory" into a calibrated pass/fail and surfacing it in the verdict banner. When no baseline exists it falls back to today's within-unit-only behavior. This is the golden-reference correlation a factory line is built on.

2. **Measurement System Analysis (this wave).** `repeatability.sh` runs the variance phase N times back to back on one unit and reports the gage's own run-to-run noise as a fraction of the fail tolerance: 6-sigma of `spread_pct` over the runs, divided by the 10-point band, read against the AIAG Gage R&R rule (under 10% capable, 10-30% marginal, over 30% the gage rivals the limit). Until that fraction is small, the limits are not trustworthy. This is the step that tells us whether the metric is even capable of a pass/fail. (It already pays off: at very short iteration settings the gage comes back inadequate, which is the honest finding that a one-second iteration is not a measurement.) Still owed: the actual characterization run on a golden unit, and reproducibility across stations and days.

3. **Precondition gating (this wave).** `--strict` promotes the AC and quiet-system warnings into hard preconditions, checked after inventory but before the load phases: a run not on AC, or on a busy system, aborts immediately instead of burning 45 minutes on a number that can't be compared to a baseline. The remaining preconditions in this leg (hot ambient, chassis-soak) need fixturing the project doesn't have; ambient is only observable post-hoc through the thermal phase, so it stays a recorded warning, not a gate.

4. **Coverage (next).** Close the audit's holes: statistical single-slow-core attribution (oversubscribe workers, accumulate per-core throughput over a longer run), longer/looped windows for intermittent defects, and treating the memory/GPU phases as real pass/fail once their baselines exist.

5. **SPC and traceability.** The hosted aggregator with per-SKU control charts, Cpk, and escape-rate tracking. The submission corpus is the data; this is where yield and drift become visible.

## Honest bottom line

Shakedown is a strong stress-screen *methodology* with the right instincts. To be a production-QA *station* it needs calibrated limits (data), a characterized gage (MSA), gated conditions, and SPC. This wave builds the calibration mechanism and wires the golden comparison into the one command. The rest is a roadmap, and most of it is gated on one thing the project has always needed and still lacks: a corpus of known-good units to characterize against. The fastest way to start is to run the screen on a unit you trust and `make-baseline.sh` it into the first golden reference.
