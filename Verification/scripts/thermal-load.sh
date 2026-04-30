#!/bin/bash
# thermal-load.sh — sustained CPU load with powermetrics sampling.
# Requires sudo (powermetrics is privileged).
# Output: JSON to stdout. Progress to stderr.
#
# Env knobs:
#   DURATION_SEC    default 600  (10 minutes)
#   SAMPLE_SEC      default 5
#   WORKERS         default = number of P-cores
#   CHASSIS_CLASS   default active-cooled-pro
#                   one of: fanless | active-cooled-pro | desktop
#                   sets thermal pass/fail thresholds (see Verification/Pass-Fail Criteria.md)

set -euo pipefail

DURATION_SEC=${DURATION_SEC:-600}
SAMPLE_SEC=${SAMPLE_SEC:-5}
WORKERS=${WORKERS:-$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null \
                      || sysctl -n hw.physicalcpu 2>/dev/null \
                      || sysctl -n hw.ncpu 2>/dev/null \
                      || echo 0)}
CHASSIS_CLASS=${CHASSIS_CLASS:-active-cooled-pro}

if [[ -z "$WORKERS" || "$WORKERS" -lt 1 ]]; then
  echo "thermal-load.sh: could not determine worker count (sysctl failed)" >&2
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  echo "thermal-load.sh requires root (powermetrics is privileged). Run with: sudo $0" >&2
  exit 1
fi

case "$CHASSIS_CLASS" in
  fanless|active-cooled-pro|desktop) ;;
  *)
    echo "thermal-load.sh: unknown CHASSIS_CLASS='$CHASSIS_CLASS'" >&2
    echo "  use one of: fanless | active-cooled-pro | desktop" >&2
    exit 2
    ;;
esac

echo "thermal-load: ${DURATION_SEC}s sustained, sample ${SAMPLE_SEC}s, $WORKERS workers, chassis=$CHASSIS_CLASS" >&2

# Proper mktemp templates (no .log-suffix bug)
PMLOG=$(mktemp -t shakedown-pm-XXXXXX)
PMERR=$(mktemp -t shakedown-pmerr-XXXXXX)
LOADLOG=$(mktemp -t shakedown-load-XXXXXX)

# Background CPU load (parallel SHA-256 forever, killed when wall-clock exceeded)
python3 - "$DURATION_SEC" "$WORKERS" > "$LOADLOG" 2>&1 <<'PYEOF' &
import hashlib, multiprocessing, sys, time

# macOS Python defaults to "spawn"; force "fork" so workers don't re-import stdin.
multiprocessing.set_start_method("fork", force=True)

DURATION = int(sys.argv[1])
WORKERS = int(sys.argv[2])
DATA = bytes(1024 * 1024)  # 1 MB of zeros — SHA-256 has no data-dependent fast paths

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

# Foreground powermetrics sampling. Capture stderr (don't swallow) and exit code
# so failures surface in the JSON instead of producing a misleading PASS.
SAMPLES=$(( (DURATION_SEC + SAMPLE_SEC - 1) / SAMPLE_SEC ))
PM_RC=0
powermetrics --samplers smc,cpu_power -i $((SAMPLE_SEC * 1000)) -n "$SAMPLES" \
  > "$PMLOG" 2> "$PMERR" || PM_RC=$?

# Stop the load (it should also be ending naturally)
kill "$LOAD_PID" 2>/dev/null || true
wait "$LOAD_PID" 2>/dev/null || true

# Parse the powermetrics log into JSON (with chassis-class verdict)
python3 - "$PMLOG" "$PMERR" "$DURATION_SEC" "$SAMPLE_SEC" "$WORKERS" "$CHASSIS_CLASS" "$PM_RC" <<'PYEOF'
import json
import re
import sys

pm_path  = sys.argv[1]
err_path = sys.argv[2]
duration = int(sys.argv[3])
sample   = int(sys.argv[4])
workers  = int(sys.argv[5])
chassis  = sys.argv[6]
pm_rc    = int(sys.argv[7])

with open(pm_path, errors="ignore") as f:
    text = f.read()
try:
    with open(err_path, errors="ignore") as f:
        err_head = "\n".join(f.read().splitlines()[:5])
except Exception:
    err_head = ""

# Split into per-sample blocks
blocks = re.split(r"\*\*\* Sampled system activity", text)
samples = []

for blk in blocks:
    if not blk.strip():
        continue
    sd = {}
    # Parse line-by-line — avoids DOTALL crossing block boundaries on malformed input.
    for line in blk.splitlines():
        m = re.search(r"CPU die temperature:\s+([\d.]+)\s*C", line)
        if m: sd["cpu_die_temp_c"] = float(m.group(1))
        m = re.search(r"GPU die temperature:\s+([\d.]+)\s*C", line)
        if m: sd["gpu_die_temp_c"] = float(m.group(1))
        m = re.search(r"Fan(?:\s+\d+)?:\s+([\d.]+)\s*rpm", line, re.I)
        if m: sd.setdefault("fan_rpm", []).append(float(m.group(1)))
        m = re.search(r"P\d*-Cluster[^\n]*?freq:\s+(\d+)\s+MHz", line, re.I)
        if m: sd.setdefault("p_cluster_freq_mhz", []).append(int(m.group(1)))
        m = re.search(r"E\d*-Cluster[^\n]*?freq:\s+(\d+)\s+MHz", line, re.I)
        if m: sd.setdefault("e_cluster_freq_mhz", []).append(int(m.group(1)))
        m = re.search(r"Combined Power \(CPU \+ GPU \+ ANE\):\s+([\d.]+)\s*mW", line)
        if m: sd["combined_power_mw"] = float(m.group(1))
    if sd:
        samples.append(sd)

def summarize(values):
    if not values:
        return None
    return {
        "n":     len(values),
        "min":   round(min(values), 2),
        "max":   round(max(values), 2),
        "mean":  round(sum(values) / len(values), 2),
        "first": round(values[0], 2),
        "last":  round(values[-1], 2),
    }

cpu_temps = [s["cpu_die_temp_c"]     for s in samples if "cpu_die_temp_c" in s]
gpu_temps = [s["gpu_die_temp_c"]     for s in samples if "gpu_die_temp_c" in s]
fan_avgs  = [sum(s["fan_rpm"]) / len(s["fan_rpm"])
             for s in samples if "fan_rpm" in s and s["fan_rpm"]]
p_freqs   = [max(s["p_cluster_freq_mhz"])
             for s in samples if s.get("p_cluster_freq_mhz")]
power_w   = [s["combined_power_mw"] / 1000.0
             for s in samples if "combined_power_mw" in s]

# Frequency cliff: largest mid-run drop, after a configurable warmup window
# (skip first ~90s to avoid the load-startup transient).
warmup = max(1, 90 // sample)
cliff_pct = None
if len(p_freqs) > warmup + 5:
    post = p_freqs[warmup:]
    peak_post = max(post)
    min_post  = min(post)
    cliff_pct = round((peak_post - min_post) / peak_post * 100, 2) if peak_post else None

# Steady-state freq vs peak observed
steady_vs_peak = None
if p_freqs:
    peak = max(p_freqs)
    tail = p_freqs[-min(12, len(p_freqs)):]  # last ~60s
    if tail and peak:
        steady_vs_peak = round(sum(tail) / len(tail) / peak * 100, 2)

# Data quality — flagged BEFORE the verdict so a no-samples run can't false-pass.
expected_min_samples = max(1, int(duration / sample / 2))  # at least half the planned samples
data_quality = "ok"
data_quality_notes = []
if pm_rc != 0:
    data_quality_notes.append(f"powermetrics exited rc={pm_rc}")
    if err_head:
        data_quality_notes.append("stderr (head): " + err_head.replace("\n", " | "))
if not samples:
    data_quality = "no_samples"
elif len(samples) < expected_min_samples:
    data_quality = "few_samples"
    data_quality_notes.append(
        f"only {len(samples)} samples captured of ~{int(duration/sample)} expected"
    )
if not p_freqs and data_quality == "ok":
    data_quality = "few_samples"
    data_quality_notes.append("no P-cluster frequency data")

# Chassis-class thresholds (mirror Verification/Pass-Fail Criteria.md)
THRESHOLDS = {
    "active-cooled-pro": {
        "cpu_temp_warn": 100, "cpu_temp_fail": 105,
        "steady_warn":   70,  "steady_fail":   60,
        "cliff_warn":    20,  "cliff_fail":    30,
        "expect_fan_ramp": True,
    },
    "fanless": {
        "cpu_temp_warn": 105, "cpu_temp_fail": 110,
        "steady_warn":   50,  "steady_fail":   40,
        "cliff_warn":    40,  "cliff_fail":    50,
        "expect_fan_ramp": False,
    },
    "desktop": {
        "cpu_temp_warn": 90,  "cpu_temp_fail": 100,
        "steady_warn":   90,  "steady_fail":   80,
        "cliff_warn":    10,  "cliff_fail":    20,
        "expect_fan_ramp": True,
    },
}
T = THRESHOLDS[chassis]

verdict = "pass"
reasons = []

# Data-quality check is fatal. No samples → no honest verdict.
if data_quality == "no_samples":
    verdict = "fail"
    reasons.append("no powermetrics samples captured — verdict cannot be trusted")
    reasons.extend(data_quality_notes)
else:
    # CPU temp
    if cpu_temps and max(cpu_temps) > T["cpu_temp_fail"]:
        verdict = "fail"
        reasons.append(f"max CPU temp {max(cpu_temps):.1f}°C > {T['cpu_temp_fail']}°C ({chassis})")
    elif cpu_temps and max(cpu_temps) > T["cpu_temp_warn"]:
        if verdict == "pass": verdict = "warn"
        reasons.append(f"max CPU temp {max(cpu_temps):.1f}°C in warn range ({chassis})")

    # Frequency cliff (mid-run)
    if cliff_pct is not None and cliff_pct > T["cliff_fail"]:
        verdict = "fail"
        reasons.append(f"frequency cliff {cliff_pct:.1f}% > {T['cliff_fail']}% ({chassis})")
    elif cliff_pct is not None and cliff_pct > T["cliff_warn"]:
        if verdict == "pass": verdict = "warn"
        reasons.append(f"frequency cliff {cliff_pct:.1f}% in warn range ({chassis})")

    # Steady-state vs peak
    if steady_vs_peak is not None and steady_vs_peak < T["steady_fail"]:
        verdict = "fail"
        reasons.append(f"steady-state {steady_vs_peak:.1f}% of peak < {T['steady_fail']}% ({chassis})")
    elif steady_vs_peak is not None and steady_vs_peak < T["steady_warn"]:
        if verdict == "pass": verdict = "warn"
        reasons.append(f"steady-state {steady_vs_peak:.1f}% in warn range ({chassis})")

    # Fan ramp (skip for fanless)
    if T["expect_fan_ramp"]:
        if not fan_avgs:
            if verdict == "pass": verdict = "warn"
            reasons.append("no fan data captured (expected fan ramp for chassis class)")
        elif max(fan_avgs) - min(fan_avgs) < 200:
            if verdict == "pass": verdict = "warn"
            reasons.append("fan RPM did not appreciably ramp under load")

    # Few-samples warning (advisory)
    if data_quality == "few_samples":
        if verdict == "pass": verdict = "warn"
        reasons.extend(data_quality_notes)

    if not reasons:
        reasons.append(f"all thresholds passed ({chassis})")

result = {
    "duration_s": duration,
    "sample_interval_s": sample,
    "workers": workers,
    "chassis_class": chassis,
    "samples_captured": len(samples),
    "data_quality": data_quality,
    "data_quality_notes": data_quality_notes,
    "powermetrics_rc": pm_rc,
    "cpu_die_temp_c": summarize(cpu_temps),
    "gpu_die_temp_c": summarize(gpu_temps),
    "fan_rpm_avg": summarize(fan_avgs),
    "p_cluster_freq_mhz": summarize(p_freqs),
    "combined_power_w": summarize(power_w),
    "frequency_cliff_pct": cliff_pct,
    "steady_state_vs_peak_pct": steady_vs_peak,
    "thresholds_used": T,
    "verdict": verdict,
    "verdict_reasons": reasons,
    "raw_log_path": pm_path,
    "raw_err_path": err_path,
}
print(json.dumps(result, indent=2))
PYEOF
