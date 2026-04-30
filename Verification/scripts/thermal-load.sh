#!/bin/bash
# thermal-load.sh — sustained CPU load with powermetrics sampling, for thermal/throttle analysis.
# Requires sudo (powermetrics is privileged).
# Output: JSON to stdout. Progress to stderr.
#
# Env knobs:
#   DURATION_SEC  default 600  (10 minutes)
#   SAMPLE_SEC    default 5
#   WORKERS       default = number of P-cores

set -euo pipefail

DURATION_SEC=${DURATION_SEC:-600}
SAMPLE_SEC=${SAMPLE_SEC:-5}
WORKERS=${WORKERS:-$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || sysctl -n hw.physicalcpu)}

if [[ $EUID -ne 0 ]]; then
  echo "thermal-load.sh requires root (powermetrics is privileged). Run with: sudo $0" >&2
  exit 1
fi

echo "thermal-load: ${DURATION_SEC}s sustained, sample ${SAMPLE_SEC}s, $WORKERS workers" >&2

PMLOG=$(mktemp -t shakedown-pm).log
LOADLOG=$(mktemp -t shakedown-load).log

# Background CPU load (parallel SHA-256 forever, killed when wall-clock exceeded)
python3 - "$DURATION_SEC" "$WORKERS" > "$LOADLOG" 2>&1 <<'PYEOF' &
import hashlib, multiprocessing, sys, time

# macOS Python defaults to "spawn"; force "fork" so workers don't re-import stdin.
multiprocessing.set_start_method("fork", force=True)

DURATION = int(sys.argv[1])
WORKERS = int(sys.argv[2])
DATA = bytes(1024 * 1024)

def worker(stop_at):
    h = hashlib.sha256()
    while time.time() < stop_at:
        for _ in range(64):
            h.update(DATA)
    return True

stop_at = time.time() + DURATION + 10  # small safety margin
with multiprocessing.Pool(WORKERS) as pool:
    pool.map(worker, [stop_at] * WORKERS)
PYEOF
LOAD_PID=$!

# Foreground powermetrics sampling for the same duration
SAMPLES=$(( (DURATION_SEC + SAMPLE_SEC - 1) / SAMPLE_SEC ))
powermetrics --samplers smc,cpu_power -i $((SAMPLE_SEC * 1000)) -n "$SAMPLES" \
  > "$PMLOG" 2>/dev/null || true

# Stop the load (it should also be ending naturally)
kill "$LOAD_PID" 2>/dev/null || true
wait "$LOAD_PID" 2>/dev/null || true

# Parse the powermetrics log into JSON
python3 - "$PMLOG" "$DURATION_SEC" "$SAMPLE_SEC" "$WORKERS" <<'PYEOF'
import json
import re
import sys

pm_path = sys.argv[1]
duration = int(sys.argv[2])
sample = int(sys.argv[3])
workers = int(sys.argv[4])

with open(pm_path, errors="ignore") as f:
    text = f.read()

# Split into per-sample blocks
blocks = re.split(r"\*\*\* Sampled system activity", text)
samples = []

for blk in blocks:
    if not blk.strip():
        continue
    sample_data = {}

    # CPU die temp
    m = re.search(r"CPU die temperature:\s+([\d.]+)\s*C", blk)
    if m:
        sample_data["cpu_die_temp_c"] = float(m.group(1))

    # GPU die temp
    m = re.search(r"GPU die temperature:\s+([\d.]+)\s*C", blk)
    if m:
        sample_data["gpu_die_temp_c"] = float(m.group(1))

    # Fan RPM (1 or 2 fans)
    fan_rpms = [float(x) for x in re.findall(r"Fan(?:\s+\d+)?:\s+([\d.]+)\s*rpm", blk, re.I)]
    if fan_rpms:
        sample_data["fan_rpm"] = fan_rpms

    # P-cluster active frequency
    p_freqs = [int(x) for x in re.findall(r"P\d*-Cluster.+?freq:\s+(\d+)\s+MHz", blk, re.DOTALL | re.I)]
    if p_freqs:
        sample_data["p_cluster_freq_mhz"] = p_freqs

    # E-cluster active frequency
    e_freqs = [int(x) for x in re.findall(r"E\d*-Cluster.+?freq:\s+(\d+)\s+MHz", blk, re.DOTALL | re.I)]
    if e_freqs:
        sample_data["e_cluster_freq_mhz"] = e_freqs

    # Package power
    m = re.search(r"Combined Power \(CPU \+ GPU \+ ANE\):\s+([\d.]+)\s*mW", blk)
    if m:
        sample_data["combined_power_mw"] = float(m.group(1))

    if sample_data:
        samples.append(sample_data)

def summarize(values):
    if not values:
        return None
    return {
        "n": len(values),
        "min": round(min(values), 2),
        "max": round(max(values), 2),
        "mean": round(sum(values) / len(values), 2),
        "first": round(values[0], 2),
        "last": round(values[-1], 2),
    }

cpu_temps = [s["cpu_die_temp_c"] for s in samples if "cpu_die_temp_c" in s]
gpu_temps = [s["gpu_die_temp_c"] for s in samples if "gpu_die_temp_c" in s]
# average across fans per sample for the summary
fan_avgs = [sum(s["fan_rpm"]) / len(s["fan_rpm"]) for s in samples if "fan_rpm" in s and s["fan_rpm"]]
# take max p-cluster freq per sample (any active P-cluster)
p_freqs = [max(s["p_cluster_freq_mhz"]) for s in samples if s.get("p_cluster_freq_mhz")]
power_w = [s["combined_power_mw"] / 1000.0 for s in samples if "combined_power_mw" in s]

# Detect frequency cliff: largest mid-run drop after warmup (skip first 18 samples ~90s)
cliff_pct = None
warmup = 18
if len(p_freqs) > warmup + 5:
    post = p_freqs[warmup:]
    peak_post = max(post)
    min_post = min(post)
    cliff_pct = round((peak_post - min_post) / peak_post * 100, 2) if peak_post else None

# Steady-state freq vs peak
steady_vs_peak = None
if p_freqs:
    peak = max(p_freqs)
    tail = p_freqs[-min(12, len(p_freqs)):]  # last ~60s
    if tail and peak:
        steady_vs_peak = round(sum(tail) / len(tail) / peak * 100, 2)

# Verdict heuristics
verdict = "pass"
reasons = []
if cpu_temps and max(cpu_temps) > 105:
    verdict = "fail"; reasons.append(f"max CPU temp {max(cpu_temps):.1f}°C > 105°C")
elif cpu_temps and max(cpu_temps) > 100:
    verdict = "warn" if verdict == "pass" else verdict
    reasons.append(f"max CPU temp {max(cpu_temps):.1f}°C in warn range")
if cliff_pct is not None and cliff_pct > 30:
    verdict = "fail"; reasons.append(f"frequency cliff {cliff_pct:.1f}% > 30%")
elif cliff_pct is not None and cliff_pct > 20:
    verdict = "warn" if verdict == "pass" else verdict
    reasons.append(f"frequency cliff {cliff_pct:.1f}% in warn range")
if steady_vs_peak is not None and steady_vs_peak < 60:
    verdict = "fail"; reasons.append(f"steady-state {steady_vs_peak:.1f}% of peak < 60%")
elif steady_vs_peak is not None and steady_vs_peak < 70:
    verdict = "warn" if verdict == "pass" else verdict
    reasons.append(f"steady-state {steady_vs_peak:.1f}% in warn range")
if not fan_avgs:
    reasons.append("no fan data captured")
elif max(fan_avgs) - min(fan_avgs) < 200:
    verdict = "warn" if verdict == "pass" else verdict
    reasons.append("fan RPM did not appreciably ramp under load")

result = {
    "duration_s": duration,
    "sample_interval_s": sample,
    "workers": workers,
    "samples_captured": len(samples),
    "cpu_die_temp_c": summarize(cpu_temps),
    "gpu_die_temp_c": summarize(gpu_temps),
    "fan_rpm_avg": summarize(fan_avgs),
    "p_cluster_freq_mhz": summarize(p_freqs),
    "combined_power_w": summarize(power_w),
    "frequency_cliff_pct": cliff_pct,
    "steady_state_vs_peak_pct": steady_vs_peak,
    "verdict": verdict,
    "verdict_reasons": reasons,
    "raw_log_path": pm_path,
}
print(json.dumps(result, indent=2))
PYEOF
