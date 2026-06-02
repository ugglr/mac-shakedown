#!/bin/bash
# compare-reports.sh: side-by-side comparison of two Shakedown reports.
#
# The harness's absolute thresholds are not yet calibrated against confirmed-good
# hardware, but the M5-class defect is unit-level: a good sibling of the same SKU
# runs fine. So the most trustworthy in-store signal is comparison, not an
# absolute pass/fail. Run the same ./run on a known-good unit (or get a friend's
# report for your exact SKU) and diff it against the unit you are verifying.
#
# Usage:
#   ./Verification/scripts/compare-reports.sh REFERENCE.json UNIT.json
#
#   REFERENCE.json  a known-good report for the same SKU (the baseline)
#   UNIT.json       the report for the unit you are verifying
#
# Output: a human-readable table to stdout. It flags every metric where the unit
# materially trails the reference (slower throughput, wider variance, hotter,
# steeper cliff). Flags are advisory: a single flag warrants a rerun, several
# flags on the same unit mean it is the weaker silicon. Comparison is only
# meaningful within the same chip + memory SKU; a mismatch is called out loudly.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $(basename "$0") REFERENCE.json UNIT.json" >&2
  echo "  REFERENCE = a known-good report for the same SKU; UNIT = the one you are verifying" >&2
  exit 2
fi

for f in "$1" "$2"; do
  if [[ ! -f "$f" ]]; then
    echo "compare-reports.sh: file not found: $f" >&2
    exit 2
  fi
done

python3 - "$1" "$2" <<'PYEOF'
import json
import sys


def load(path):
    with open(path) as f:
        return json.load(f)


ref = load(sys.argv[1])
unit = load(sys.argv[2])
ref_name = sys.argv[1].rsplit("/", 1)[-1]
unit_name = sys.argv[2].rsplit("/", 1)[-1]


def get(report, phase_key, path):
    node = report.get("phases", {}).get(phase_key, {}).get("details", {})
    for key in path:
        if not isinstance(node, dict):
            return None
        node = node.get(key)
    return node if isinstance(node, (int, float)) else None


def uinfo(report):
    u = report.get("unit", {}) or {}
    return u.get("chip"), u.get("memory_gb")


# (label, phase_key, details-path, higher_is_better, kind, flag_threshold)
#   kind: rel = percent change; pp = percentage-point delta; ratio = absolute
#         delta on a ratio; abs = absolute delta (degrees C).
SPECS = [
    ("CPU variance mean (MB/s)",     "4_cpu_variance",          ["mean_mb_per_s"],            True,  "rel",  10),
    ("CPU variance spread (%)",      "4_cpu_variance",          ["spread_pct"],               False, "pp",    3),
    ("CPU max/min ratio",            "4_cpu_variance",          ["max_to_min_ratio"],         False, "ratio", 0.1),
    ("Non-accel mean (MB/s)",        "4b_cpu_variance_noaccel", ["mean_mb_per_s"],            True,  "rel",  10),
    ("Non-accel spread (%)",         "4b_cpu_variance_noaccel", ["spread_pct"],               False, "pp",    3),
    ("Race xz (MB/s)",               "10_race_bench",           ["throughput_mb_per_s"],      True,  "rel",  10),
    ("SSD read (MB/s)",              "11_ssd_test",             ["read_mb_per_s"],            True,  "rel",  12),
    ("SSD write (MB/s)",             "11_ssd_test",             ["write_mb_per_s"],           True,  "rel",  12),
    ("Memory triad (GB/s)",          "12_memory_bandwidth",     ["mean_triad_gb_per_s"],      True,  "rel",  10),
    ("Memory copy (GB/s)",           "12_memory_bandwidth",     ["mean_copy_gb_per_s"],       True,  "rel",  10),
    ("GPU compute (GFLOP/s)",        "13_gpu_variance",         ["mean_gflops"],              True,  "rel",  10),
    ("llama gen (tok/s)",            "14_llama_bench",          ["gen_tok_per_s"],            True,  "rel",  10),
    ("llama prompt (tok/s)",         "14_llama_bench",          ["prompt_tok_per_s"],         True,  "rel",  10),
    ("Thermal steady vs peak (%)",   "5_thermal_load",          ["steady_state_vs_peak_pct"], True,  "pp",    5),
    ("Thermal early cliff (%)",      "5_thermal_load",          ["early_cliff_pct"],          False, "pp",   10),
    ("CPU temp max (C)",             "5_thermal_load",          ["cpu_die_temp_c", "max"],    False, "abs",   5),
]


def fmt(v):
    if v is None:
        return "n/a"
    return f"{v:,.2f}" if isinstance(v, float) else f"{v:,}"


rows = []
flags = []
for label, pk, path, higher, kind, thr in SPECS:
    a = get(ref, pk, path)
    b = get(unit, pk, path)
    delta_str = "n/a"
    flagged = False
    if a is not None and b is not None:
        if kind == "rel":
            d = (b - a) / a * 100 if a else 0.0
            delta_str = f"{d:+.1f}%"
            flagged = (higher and d <= -thr) or (not higher and d >= thr)
        elif kind == "pp":
            d = b - a
            delta_str = f"{d:+.1f}pp"
            flagged = (higher and d <= -thr) or (not higher and d >= thr)
        elif kind == "ratio":
            d = b - a
            delta_str = f"{d:+.2f}"
            flagged = (b >= a + thr) and (b >= 1.2)
        elif kind == "abs":
            d = b - a
            delta_str = f"{d:+.1f}"
            flagged = (not higher and d >= thr) or (higher and d <= -thr)
    rows.append((label, fmt(a), fmt(b), delta_str, "<-- unit trails" if flagged else ""))
    if flagged:
        flags.append(label)

ref_chip, ref_mem = uinfo(ref)
unit_chip, unit_mem = uinfo(unit)

print(f"shakedown compare")
print(f"  reference: {ref_name}  [{ref_chip or '?'}, {ref_mem or '?'} GB]")
print(f"  unit:      {unit_name}  [{unit_chip or '?'}, {unit_mem or '?'} GB]")
if (ref_chip and unit_chip and ref_chip != unit_chip) or (ref_mem and unit_mem and ref_mem != unit_mem):
    print()
    print("  WARNING: different SKU (chip or memory). Comparison is only meaningful")
    print("  within the same chip + memory config. Deltas below are not trustworthy.")
print()
print(f"  {'metric':<28} {'reference':>12} {'unit':>12} {'delta':>9}   note")
print(f"  {'-'*28} {'-'*12} {'-'*12} {'-'*9}   {'-'*16}")
for label, a, b, d, note in rows:
    print(f"  {label:<28} {a:>12} {b:>12} {d:>9}   {note}")
print()
if flags:
    print(f"  Unit trails the reference on {len(flags)} metric(s): {', '.join(flags)}.")
    if len(flags) == 1:
        print("  One flag: rerun the unit (single-warn discipline) before reading into it.")
    else:
        print("  Several flags on the same unit point at the weaker silicon. Investigate,")
        print("  rerun, and prefer the stronger unit while you can still exchange.")
else:
    print("  No metric materially trails the reference: the unit looks consistent with")
    print("  a known-good sibling of this SKU (within the comparison thresholds).")
print()
print("  Advisory only: thresholds compare relative health, not absolute pass/fail.")
PYEOF
