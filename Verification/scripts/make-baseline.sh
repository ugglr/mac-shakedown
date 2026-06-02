#!/bin/bash
# make-baseline.sh: build a calibrated baseline from known-good Shakedown reports.
#
# A production screen needs limits derived from known-good parts, not from public
# reports. This ingests N reports from KNOWN-GOOD units of the SAME SKU and, per
# metric, computes a golden value (the median) and an acceptance limit:
#   - with >= 8 samples: a 3-sigma control limit (golden -+ 3*stdev)
#   - below that: a tolerance band (golden * (1 -+ BASELINE_TOLERANCE_PCT))
# `./run` bins a unit-under-test against baselines/<preset>.json when it exists,
# turning the verdict from advisory into a calibrated pass/fail. Regenerate as the
# corpus grows; more known-good samples means tighter, more trustworthy limits.
#
# Usage:
#   ./Verification/scripts/make-baseline.sh good1.json good2.json ... > baselines/<preset>.json
#
# Env:
#   BASELINE_TOLERANCE_PCT   default 15  (band used when fewer than 8 samples)

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") good1.json [good2.json ...] > baselines/<preset>.json" >&2
  echo "  inputs are Shakedown reports from KNOWN-GOOD units of the same SKU" >&2
  exit 2
fi

for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    echo "make-baseline.sh: file not found: $f" >&2
    exit 2
  fi
done

TOL=${BASELINE_TOLERANCE_PCT:-15}
if ! [[ "$TOL" =~ ^[0-9]+$ ]]; then
  echo "make-baseline.sh: BASELINE_TOLERANCE_PCT must be an integer (got '$TOL')" >&2
  exit 2
fi

python3 - "$TOL" "$@" <<'PYEOF'
import json
import statistics
import sys

tol = float(sys.argv[1]) / 100.0
paths = sys.argv[2:]

# (phase_key, details-path, higher_is_better). These are the metrics a baseline
# bins against. Higher-is-better gets a `min` limit; lower-is-better a `max`.
METRICS = [
    ("4_cpu_variance",          ["mean_mb_per_s"],            True),
    ("4_cpu_variance",          ["spread_pct"],               False),
    ("4b_cpu_variance_noaccel", ["mean_mb_per_s"],            True),
    ("12_memory_bandwidth",     ["mean_triad_gb_per_s"],      True),
    ("12_memory_bandwidth",     ["mean_copy_gb_per_s"],       True),
    ("13_gpu_variance",         ["mean_gflops"],              True),
    ("5_thermal_load",          ["steady_state_vs_peak_pct"], True),
    ("5_thermal_load",          ["cpu_die_temp_c", "max"],    False),
    ("10_race_bench",           ["throughput_mb_per_s"],      True),
    ("11_ssd_test",             ["read_mb_per_s"],            True),
    ("11_ssd_test",             ["write_mb_per_s"],           True),
]

reports = []
for p in paths:
    with open(p) as f:
        reports.append(json.load(f))


def get(report, phase_key, path):
    node = report.get("phases", {}).get(phase_key, {}).get("details", {})
    for key in path:
        if not isinstance(node, dict):
            return None
        node = node.get(key)
    return node if isinstance(node, (int, float)) else None


chips = {r.get("unit", {}).get("chip") for r in reports}
mems = {r.get("unit", {}).get("memory_gb") for r in reports}
if len([c for c in chips if c]) > 1 or len([m for m in mems if m]) > 1:
    print("make-baseline.sh: WARNING: inputs span more than one SKU "
          f"(chips={sorted(c for c in chips if c)}, memory={sorted(m for m in mems if m)}). "
          "A baseline is only meaningful within one chip + memory config.", file=sys.stderr)

preset = reports[0].get("target", {}).get("preset")
metrics = {}
for phase_key, path, higher in METRICS:
    vals = [v for v in (get(r, phase_key, path) for r in reports) if v is not None]
    if not vals:
        continue
    golden = round(statistics.median(vals), 3)
    entry = {"golden": golden, "higher_better": higher, "n": len(vals)}
    if len(vals) >= 8:
        sd = statistics.stdev(vals)
        entry["sigma"] = round(sd, 3)
        if higher:
            entry["min"] = round(golden - 3 * sd, 3)
        else:
            entry["max"] = round(golden + 3 * sd, 3)
    else:
        if higher:
            entry["min"] = round(golden * (1 - tol), 3)
        else:
            entry["max"] = round(golden * (1 + tol), 3)
    metrics[phase_key + "." + ".".join(path)] = entry

out = {
    "preset": preset,
    "chip": (sorted(c for c in chips if c)[0] if len([c for c in chips if c]) == 1
             else sorted(c for c in chips if c)),
    "memory_gb": (sorted(m for m in mems if m)[0] if len([m for m in mems if m]) == 1
                  else sorted(m for m in mems if m)),
    "n_samples": len(reports),
    "tolerance_pct": float(sys.argv[1]),
    "note": ("golden = median of known-good units; limit = 3-sigma control limit "
             "when n >= 8, else golden +- tolerance. Regenerate as the corpus grows."),
    "metrics": metrics,
}
print(json.dumps(out, indent=2))
PYEOF
