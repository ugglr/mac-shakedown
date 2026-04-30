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
#                   sets thermal pass/fail thresholds (Verification/Pass-Fail Criteria.md)

set -euo pipefail

DURATION_SEC=${DURATION_SEC:-600}
SAMPLE_SEC=${SAMPLE_SEC:-5}
CHASSIS_CLASS=${CHASSIS_CLASS:-active-cooled-pro}

# WORKERS: probe P-cores then fall back; treat empty string as unset.
if [[ -z "${WORKERS:-}" ]]; then
  WORKERS=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null \
            || sysctl -n hw.physicalcpu 2>/dev/null \
            || sysctl -n hw.ncpu 2>/dev/null \
            || echo "")
fi
if ! [[ "$WORKERS" =~ ^[0-9]+$ ]] || (( WORKERS < 1 )); then
  echo "thermal-load.sh: could not determine worker count (sysctl failed)" >&2
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  echo "thermal-load.sh requires root (powermetrics is privileged). Run with: sudo $0" >&2
  exit 1
fi

case "$CHASSIS_CLASS" in
  fanless|active-cooled-pro|desktop|intel-laptop|intel-desktop) ;;
  *)
    echo "thermal-load.sh: unknown CHASSIS_CLASS='$CHASSIS_CLASS'" >&2
    echo "  use one of: fanless | active-cooled-pro | desktop | intel-laptop | intel-desktop" >&2
    exit 2
    ;;
esac

if (( DURATION_SEC < 5 * SAMPLE_SEC )); then
  echo "thermal-load.sh: DURATION_SEC ($DURATION_SEC) < 5*SAMPLE_SEC ($((5*SAMPLE_SEC))) — too short to sample meaningfully" >&2
  exit 2
fi

echo "thermal-load: ${DURATION_SEC}s sustained, sample ${SAMPLE_SEC}s, $WORKERS workers, chassis=$CHASSIS_CLASS" >&2

# Proper mktemp templates (no .log-suffix bug).
PMLOG=$(mktemp -t shakedown-pm.XXXXXX)
PMERR=$(mktemp -t shakedown-pmerr.XXXXXX)
LOADLOG=$(mktemp -t shakedown-load.XXXXXX)

# Cleanup trap — kills the entire load process group (not just the parent
# Python) on exit, removes ephemeral logs but keeps PMLOG referenced in JSON.
LOAD_PGID=""
cleanup() {
  if [[ -n "$LOAD_PGID" ]]; then
    # Send TERM to the whole process group, wait briefly, then KILL stragglers.
    kill -TERM -- "-$LOAD_PGID" 2>/dev/null || true
    sleep 0.5
    kill -KILL -- "-$LOAD_PGID" 2>/dev/null || true
  fi
  rm -f "$LOADLOG" "$PMERR"
  # PMLOG is intentionally retained — referenced in `raw_log_path`.
}
trap cleanup EXIT INT TERM

# Background CPU load — runs in its own process group so we can kill the
# multiprocessing pool workers, not just the parent.
set -m  # enable job control so the next backgrounded command becomes its own pgrp
python3 - "$DURATION_SEC" "$WORKERS" > "$LOADLOG" 2>&1 <<'PYEOF' &
import hashlib, multiprocessing, sys, time

# macOS Python defaults to "spawn"; force "fork" so workers don't re-import stdin.
multiprocessing.set_start_method("fork", force=True)

DURATION = int(sys.argv[1])
WORKERS = int(sys.argv[2])
DATA = bytes(1024 * 1024)  # SHA-256 has no data-dependent fast paths

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
LOAD_PGID=$(ps -o pgid= -p "$LOAD_PID" | tr -d ' ' || echo "$LOAD_PID")
set +m

# Foreground powermetrics sampling. Capture stderr (don't swallow) and exit code
# so failures surface in the JSON instead of producing a misleading PASS.
SAMPLES=$(( (DURATION_SEC + SAMPLE_SEC - 1) / SAMPLE_SEC ))
PM_RC=0
powermetrics --samplers smc,cpu_power,thermal -i $((SAMPLE_SEC * 1000)) -n "$SAMPLES" \
  > "$PMLOG" 2> "$PMERR" || PM_RC=$?

# Stop the load (process group, not just parent).
if [[ -n "$LOAD_PGID" ]]; then
  kill -TERM -- "-$LOAD_PGID" 2>/dev/null || true
fi
wait "$LOAD_PID" 2>/dev/null || true
LOAD_PGID=""  # disable trap re-kill, already done

# Parse the powermetrics log into JSON (with chassis-class verdict + data_quality).
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

with open(pm_path, encoding="utf-8", errors="ignore") as f:
    text = f.read()
try:
    with open(err_path, encoding="utf-8", errors="ignore") as f:
        err_head = "\n".join(f.read().splitlines()[:5])
except Exception:
    err_head = ""

# Split into per-sample blocks.
blocks = re.split(r"\*\*\* Sampled system activity", text)
samples = []

for blk in blocks:
    if not blk.strip():
        continue
    sd = {}
    fan_lines_in_block = 0
    # Parse line-by-line — avoids DOTALL crossing block boundaries on malformed input.
    for line in blk.splitlines():
        m = re.search(r"CPU die temperature:\s+([\d.]+)\s*C", line)
        if m: sd["cpu_die_temp_c"] = float(m.group(1))
        m = re.search(r"GPU die temperature:\s+([\d.]+)\s*C", line)
        if m: sd["gpu_die_temp_c"] = float(m.group(1))
        # Ambient / chassis / battery / SoC temps — capture whatever powermetrics emits.
        # Names vary by macOS version: Ambient, Battery temperature, etc.
        m = re.search(r"(Ambient|Battery|Bottom (?:Skin|case)|Top Skin|Outside)\s*(?:temperature)?:\s*([\d.]+)\s*C",
                      line, re.I)
        if m:
            sd.setdefault("ambient_temps_c", {})[m.group(1).lower()] = float(m.group(2))
        # Fan: handles "Fan: 2400 rpm", "Fan 1: ...", "Fans: 2", per-fan "Fan 0:" lines.
        m = re.search(r"^\s*Fans?(?:\s+\d+)?:\s+([\d.]+)\s*rpm\s*$", line, re.I)
        if m:
            sd.setdefault("fan_rpm", []).append(float(m.group(1)))
            fan_lines_in_block += 1
        m = re.search(r"P\d*-Cluster[^\n]*?freq:\s+(\d+)\s+MHz", line, re.I)
        if m: sd.setdefault("p_cluster_freq_mhz", []).append(int(m.group(1)))
        m = re.search(r"E\d*-Cluster[^\n]*?freq:\s+(\d+)\s+MHz", line, re.I)
        if m: sd.setdefault("e_cluster_freq_mhz", []).append(int(m.group(1)))
        # Apple Silicon combined power
        m = re.search(r"Combined Power \(CPU \+ GPU \+ ANE\):\s+([\d.]+)\s*mW", line)
        if m: sd["combined_power_mw"] = float(m.group(1))
        # Intel: per-CPU frequency lines look like "CPU 0 frequency: 3192 MHz"
        m = re.search(r"^\s*CPU\s+\d+\s+frequency:\s+(\d+)\s+MHz", line)
        if m: sd.setdefault("intel_cpu_freq_mhz", []).append(int(m.group(1)))
        # Intel: package and IA-cores power
        m = re.search(r"Package Power:\s+([\d.]+)\s*mW", line)
        if m: sd["intel_package_power_mw"] = float(m.group(1))
        m = re.search(r"IA Cores Power:\s+([\d.]+)\s*mW", line)
        if m: sd["intel_ia_cores_power_mw"] = float(m.group(1))
        m = re.search(r"GT Cores Power:\s+([\d.]+)\s*mW", line)
        if m: sd["intel_gt_cores_power_mw"] = float(m.group(1))
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

# Frequency: prefer Apple Silicon P-cluster, fall back to Intel per-CPU max.
p_freqs = [max(s["p_cluster_freq_mhz"])
           for s in samples if s.get("p_cluster_freq_mhz")]
if not p_freqs:
    p_freqs = [max(s["intel_cpu_freq_mhz"])
               for s in samples if s.get("intel_cpu_freq_mhz")]

# Power: prefer Apple Silicon combined, fall back to Intel package power.
power_w = [s["combined_power_mw"] / 1000.0
           for s in samples if "combined_power_mw" in s]
if not power_w:
    power_w = [s["intel_package_power_mw"] / 1000.0
               for s in samples if "intel_package_power_mw" in s]

# Ambient / chassis temps — collect the FIRST sample's reading (closest to
# pre-load conditions) and the maximum during the run.
ambient_first = None
ambient_max = None
for i, s in enumerate(samples):
    if "ambient_temps_c" not in s:
        continue
    # Prefer "ambient" if reported, else any other sensor.
    val = s["ambient_temps_c"].get("ambient") or next(iter(s["ambient_temps_c"].values()))
    if ambient_first is None:
        ambient_first = val
    if ambient_max is None or val > ambient_max:
        ambient_max = val

# Frequency cliffs — split into "early" (first 30 s) and "post-warmup" (after 90 s).
# The textbook bad-batch signature is a cliff to base clock within 30 s under load,
# which the previous version's 90 s warmup-skip threw away.
early_window = max(1, 30 // sample)
warmup_skip  = max(1, 90 // sample)

early_cliff_pct = None
if len(p_freqs) > early_window + 2:
    early = p_freqs[:early_window]
    if early:
        peak_early = max(early)
        min_early  = min(early)
        if peak_early:
            early_cliff_pct = round((peak_early - min_early) / peak_early * 100, 2)

cliff_pct = None
if len(p_freqs) > warmup_skip + 5:
    post = p_freqs[warmup_skip:]
    peak_post = max(post)
    min_post  = min(post)
    cliff_pct = round((peak_post - min_post) / peak_post * 100, 2) if peak_post else None

# Steady-state freq vs peak observed
steady_vs_peak = None
if p_freqs:
    peak = max(p_freqs)
    tail = p_freqs[-min(12, len(p_freqs)):]  # last ~60 s
    if tail and peak:
        steady_vs_peak = round(sum(tail) / len(tail) / peak * 100, 2)

# Data quality — flagged BEFORE the verdict so a no-samples run can't false-pass.
expected_min_samples = max(1, int(duration / sample / 2))
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

# Chassis-class thresholds (mirror Verification/Pass-Fail Criteria.md).
THRESHOLDS = {
    "active-cooled-pro": {
        "cpu_temp_warn": 100, "cpu_temp_fail": 105,
        "steady_warn":   70,  "steady_fail":   60,
        "cliff_warn":    20,  "cliff_fail":    30,
        "early_cliff_warn": 25, "early_cliff_fail": 40,
        "expect_fan_ramp": True,
    },
    "fanless": {
        "cpu_temp_warn": 105, "cpu_temp_fail": 110,
        "steady_warn":   50,  "steady_fail":   40,
        "cliff_warn":    40,  "cliff_fail":    50,
        "early_cliff_warn": 50, "early_cliff_fail": 70,  # Air throttles by design
        "expect_fan_ramp": False,
    },
    "desktop": {
        "cpu_temp_warn": 90,  "cpu_temp_fail": 100,
        "steady_warn":   90,  "steady_fail":   80,
        "cliff_warn":    10,  "cliff_fail":    20,
        "early_cliff_warn": 15, "early_cliff_fail": 25,
        "expect_fan_ramp": True,
    },
    # Intel laptops throttle hard by design — looser steady-state and cliff
    # thresholds. Tjmax is typically 100°C and Intel throttles aggressively
    # well before that.
    "intel-laptop": {
        "cpu_temp_warn":  98, "cpu_temp_fail": 105,
        "steady_warn":    50, "steady_fail":   35,
        "cliff_warn":     35, "cliff_fail":    50,
        "early_cliff_warn": 40, "early_cliff_fail": 55,
        "expect_fan_ramp": True,
    },
    "intel-desktop": {  # iMac, Mac mini Intel
        "cpu_temp_warn":  90, "cpu_temp_fail": 100,
        "steady_warn":    75, "steady_fail":   60,
        "cliff_warn":     20, "cliff_fail":    30,
        "early_cliff_warn": 25, "early_cliff_fail": 40,
        "expect_fan_ramp": True,
    },
}
T = THRESHOLDS[chassis]

fail_signals = []
warn_signals = []

if data_quality == "no_samples":
    fail_signals.append("no powermetrics samples captured — verdict cannot be trusted")
    fail_signals.extend(data_quality_notes)
else:
    # CPU temp
    if cpu_temps and max(cpu_temps) > T["cpu_temp_fail"]:
        fail_signals.append(f"max CPU temp {max(cpu_temps):.1f}°C > {T['cpu_temp_fail']}°C ({chassis})")
    elif cpu_temps and max(cpu_temps) > T["cpu_temp_warn"]:
        warn_signals.append(f"max CPU temp {max(cpu_temps):.1f}°C in warn range ({chassis})")

    # Early cliff (first 30 s) — the textbook bad-batch signature
    if early_cliff_pct is not None and early_cliff_pct > T["early_cliff_fail"]:
        fail_signals.append(
            f"early-window frequency cliff {early_cliff_pct:.1f}% > {T['early_cliff_fail']}% "
            f"({chassis}) — textbook bad-batch signature"
        )
    elif early_cliff_pct is not None and early_cliff_pct > T["early_cliff_warn"]:
        warn_signals.append(
            f"early-window frequency cliff {early_cliff_pct:.1f}% in warn range ({chassis})"
        )

    # Mid-run frequency cliff (post-warmup)
    if cliff_pct is not None and cliff_pct > T["cliff_fail"]:
        fail_signals.append(f"frequency cliff {cliff_pct:.1f}% > {T['cliff_fail']}% ({chassis})")
    elif cliff_pct is not None and cliff_pct > T["cliff_warn"]:
        warn_signals.append(f"frequency cliff {cliff_pct:.1f}% in warn range ({chassis})")

    # Steady-state vs peak
    if steady_vs_peak is not None and steady_vs_peak < T["steady_fail"]:
        fail_signals.append(f"steady-state {steady_vs_peak:.1f}% of peak < {T['steady_fail']}% ({chassis})")
    elif steady_vs_peak is not None and steady_vs_peak < T["steady_warn"]:
        warn_signals.append(f"steady-state {steady_vs_peak:.1f}% in warn range ({chassis})")

    # Fan ramp (skip for fanless)
    if T["expect_fan_ramp"]:
        if not fan_avgs:
            warn_signals.append("no fan data captured (expected fan ramp for chassis class)")
        elif max(fan_avgs) - min(fan_avgs) < 200:
            warn_signals.append("fan RPM did not appreciably ramp under load")

    if data_quality == "few_samples":
        warn_signals.extend(data_quality_notes)

# Compound-warn escalation: 3+ warn signals on a thermal test = effectively a fail.
verdict = "pass"
if fail_signals:
    verdict = "fail"
elif len(warn_signals) >= 3:
    verdict = "fail"
    fail_signals.append(
        f"compound warning ({len(warn_signals)} independent warn signals) — escalated to fail"
    )
elif warn_signals:
    verdict = "warn"

reasons = fail_signals + warn_signals if (fail_signals or warn_signals) else \
          [f"all thresholds passed ({chassis})"]

result = {
    "duration_s": duration,
    "sample_interval_s": sample,
    "workers": workers,
    "chassis_class": chassis,
    "samples_captured": len(samples),
    "data_quality": data_quality,
    "data_quality_notes": data_quality_notes,
    "powermetrics_rc": pm_rc,
    "ambient_temp_c": {
        "first_sample": ambient_first,
        "max_during_run": ambient_max,
    },
    "cpu_die_temp_c": summarize(cpu_temps),
    "gpu_die_temp_c": summarize(gpu_temps),
    "fan_rpm_avg": summarize(fan_avgs),
    "p_cluster_freq_mhz": summarize(p_freqs),
    "combined_power_w": summarize(power_w),
    "early_cliff_pct": early_cliff_pct,
    "frequency_cliff_pct": cliff_pct,
    "steady_state_vs_peak_pct": steady_vs_peak,
    "thresholds_used": T,
    "verdict": verdict,
    "verdict_reasons": reasons,
    "raw_log_path": pm_path,
}
print(json.dumps(result, indent=2))
PYEOF
