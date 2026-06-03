#!/bin/bash
# repeatability.sh: Measurement System Analysis (gage repeatability) for the
# variance screen.
#
# Before you trust a pass/fail, you have to trust the measurement. This runs
# Phase 4 (cpu-variance) N times back to back on ONE unit and asks: how much of
# the fail tolerance does our own run-to-run noise eat? If the gage error is a
# large fraction of the limit it decides against, the pass/fail is noise, not
# signal. This is the repeatability half of Gage R&R (one unit, one station,
# back to back); reproducibility across stations/days is a separate, later step.
#
# Run it on a unit you BELIEVE is good and stable. The spread of spread_pct
# across runs is then the gage's own noise. If the unit is itself defective or
# intermittent, that noise is inflated by the unit, not the gage, and the
# capability verdict is pessimistic (which is the safe direction).
#
# Usage:
#   ./Verification/scripts/repeatability.sh > msa-<preset>.json
#
# Env:
#   REPEAT_N   default 5   (number of back-to-back runs; >= 2)
#   plus every cpu-variance.sh knob (WARMUP_SEC, ITERATIONS, SECONDS_PER_ITER,
#   CHASSIS_CLASS, WORKLOAD, ...) passes straight through.
#
# Takt warning: each run is a full variance phase. REPEAT_N=5 is ~5x the
# variance runtime (tens of minutes on default settings). That is expected for a
# characterization step; it is not a per-unit production check.

set -euo pipefail

REPEAT_N=${REPEAT_N:-5}
if ! [[ "$REPEAT_N" =~ ^[0-9]+$ ]] || [[ "$REPEAT_N" -lt 2 ]]; then
  echo "repeatability.sh: REPEAT_N must be an integer >= 2 (got '$REPEAT_N')" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIANCE="$SCRIPT_DIR/cpu-variance.sh"
if [[ ! -x "$VARIANCE" ]]; then
  echo "repeatability.sh: cannot find cpu-variance.sh next to this script" >&2
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for ((i = 1; i <= REPEAT_N; i++)); do
  echo "repeatability: run $i/$REPEAT_N (a full variance phase) ..." >&2
  # Keep going even if a run exits non-zero; the JSON is the record, and the
  # python pass validates and skips anything that did not produce one.
  "$VARIANCE" >"$WORK/run_$i.json" 2>/dev/null || true
done

python3 - "$REPEAT_N" "$WORK" <<'PYEOF'
import json
import os
import statistics
import sys

n = int(sys.argv[1])
work = sys.argv[2]

# spread_pct is the variance screen's decision metric: fail above this many
# points. The gage's job is to resolve a defect well inside this band.
TOLERANCE = 10.0

runs = []
for i in range(1, n + 1):
    path = os.path.join(work, f"run_{i}.json")
    try:
        with open(path) as f:
            d = json.load(f)
    except (OSError, ValueError):
        continue
    mean = d.get("mean_mb_per_s")
    spread = d.get("spread_pct")
    if isinstance(mean, (int, float)) and isinstance(spread, (int, float)):
        runs.append({"run": i, "mean_mb_per_s": mean, "spread_pct": spread})

if len(runs) < 2:
    print(json.dumps({
        "tool": "repeatability",
        "n_runs": n,
        "n_valid": len(runs),
        "verdict": "error",
        "note": "fewer than 2 valid runs; cannot characterize repeatability.",
    }, indent=2))
    sys.exit(1)

throughputs = [r["mean_mb_per_s"] for r in runs]
spreads = [r["spread_pct"] for r in runs]

t_mean = statistics.mean(throughputs)
t_sd = statistics.stdev(throughputs)
t_cv = (t_sd / t_mean * 100) if t_mean else 0.0

s_sd = statistics.stdev(spreads)
# 6-sigma study variation is the standard MSA span of the measurement.
study_variation = 6 * s_sd
pct_of_tol = study_variation / TOLERANCE * 100

# AIAG Gage R&R rule of thumb against the tolerance.
if pct_of_tol < 10:
    capability = "capable"
    verdict = "pass"
elif pct_of_tol <= 30:
    capability = "marginal"
    verdict = "warn"
else:
    capability = "inadequate"
    verdict = "fail"

out = {
    "tool": "repeatability",
    "phase": "4_cpu_variance",
    "decision_metric": "spread_pct",
    "tolerance_pct": TOLERANCE,
    "n_runs": n,
    "n_valid": len(runs),
    "runs": runs,
    "throughput": {
        "mean_mb_per_s": round(t_mean, 1),
        "stdev_mb_per_s": round(t_sd, 1),
        "cv_pct": round(t_cv, 3),
    },
    "spread_pct_stat": {
        "mean": round(statistics.mean(spreads), 3),
        "stdev": round(s_sd, 3),
        "min": round(min(spreads), 3),
        "max": round(max(spreads), 3),
    },
    "gage": {
        "study_variation_6sigma": round(study_variation, 3),
        "pct_of_tolerance": round(pct_of_tol, 1),
        "capability": capability,
    },
    "verdict": verdict,
    "note": ("Repeatability only (one unit, back to back). pct_of_tolerance is "
             "6-sigma of spread_pct over the runs, as a fraction of the 10-point "
             "fail band: < 10% capable, 10-30% marginal, > 30% the gage noise "
             "rivals the limit. Run on a unit you trust; an intermittent unit "
             "inflates this. Reproducibility across stations/days is separate."),
}
print(json.dumps(out, indent=2))

# Human summary, last thing on screen.
c = capability.upper()
print("", file=sys.stderr)
print(f"  MSA repeatability: {len(runs)} runs, "
      f"spread_pct {out['spread_pct_stat']['min']}-{out['spread_pct_stat']['max']} "
      f"(throughput CV {out['throughput']['cv_pct']}%)", file=sys.stderr)
print(f"  Gage is {pct_of_tol:.1f}% of the {TOLERANCE:.0f}-point tolerance -> {c}",
      file=sys.stderr)
PYEOF
